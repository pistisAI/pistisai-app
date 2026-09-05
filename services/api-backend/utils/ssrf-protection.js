/**
 * SSRF Protection Utility
 *
 * Prevents Server-Side Request Forgery by validating URLs against
 * private/internal IP ranges before allowing outbound HTTP requests.
 *
 * Blocks: loopback (127.0.0.0/8), RFC1918 private (10.0.0.0/8,
 * 172.16.0.0/12, 192.168.0.0/16), link-local (169.254.0/16),
 * cloud metadata (169.254.169.254), and IPv6 loopback/link-local.
 */

import net from 'net';
import dns from 'dns';
import { promisify } from 'util';

const dnsLookup = promisify(dns.lookup);

// Networks that must never be targeted by outbound requests
const BLOCKED_NETWORKS = [
  { cidr: '127.0.0.0/8', label: 'loopback' },
  { cidr: '10.0.0.0/8', label: 'RFC1918 private' },
  { cidr: '172.16.0.0/12', label: 'RFC1918 private' },
  { cidr: '192.168.0.0/16', label: 'RFC1918 private' },
  { cidr: '169.254.0.0/16', label: 'link-local' },
  { cidr: '0.0.0.0/8', label: 'current network' },
];

function ipToLong(ip) {
  return ip.split('.').reduce((acc, octet) => (acc << 8) + parseInt(octet, 10), 0) >>> 0;
}

function isInCidr(ip, cidr) {
  const [network, prefixStr] = cidr.split('/');
  const prefixLen = parseInt(prefixStr, 10);
  const ipLong = ipToLong(ip);
  const netLong = ipToLong(network);
  const mask = prefixLen === 0 ? 0 : (-1 << (32 - prefixLen)) >>> 0;
  return (ipLong & mask) === (netLong & mask);
}

function isPrivateIp(ip) {
  if (!net.isIPv4(ip)) return false;
  for (const { cidr, label } of BLOCKED_NETWORKS) {
    if (isInCidr(ip, cidr)) return label;
  }
  return false;
}

/**
 * Check if a URL is safe to request (not pointing to internal networks).
 * @param {string} targetUrl - The URL to validate
 * @returns {Promise<{safe: boolean, reason?: string}>}
 */
export async function isUrlSafe(targetUrl) {
  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch {
    return { safe: false, reason: 'Invalid URL format' };
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    return { safe: false, reason: `Invalid protocol: ${parsed.protocol}` };
  }

  const hostname = parsed.hostname;

  // Check literal IP addresses
  if (net.isIP(hostname)) {
    if (net.isIPv4(hostname)) {
      const blockReason = isPrivateIp(hostname);
      if (blockReason) {
        return { safe: false, reason: `Blocked ${blockReason} IP: ${hostname}` };
      }
    } else {
      // IPv6 checks
      if (hostname === '::1' || hostname.startsWith('fe80') || hostname.startsWith('fc') || hostname.startsWith('fd')) {
        return { safe: false, reason: `Blocked IPv6 address: ${hostname}` };
      }
    }
  }

  // DNS resolution check — prevents DNS rebinding to internal IPs
  try {
    const { address } = await dnsLookup(hostname);
    if (net.isIPv4(address)) {
      const blockReason = isPrivateIp(address);
      if (blockReason) {
        return { safe: false, reason: `DNS resolved to blocked ${blockReason} IP: ${address}` };
      }
    }
  } catch (err) {
    return { safe: false, reason: `DNS lookup failed: ${err.message}` };
  }

  return { safe: true };
}
