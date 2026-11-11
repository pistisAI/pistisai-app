#!/usr/bin/env node

/**
 * Health Check Verification Script
 * Tests all health check endpoints across PistisAI services
 * 
 * Usage: node test-health-checks.js
 */

import http from 'http';

const services = [
  {
    name: 'api-backend',
    port: 3000,
    endpoints: ['/health', '/healthz', '/ready'],
  },
  {
    name: 'streaming-proxy',
    port: 3001,
    endpoints: ['/health', '/ready'],
  },
  {
    name: 'tailscale-relay',
    port: 3002,
    endpoints: ['/health', '/ready'],
  },
];

/**
 * Make HTTP request to service endpoint
 */
async function testEndpoint(host, port, path) {
  return new Promise((resolve) => {
    const options = {
      hostname: host,
      port,
      path,
      method: 'GET',
      timeout: 5000,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: data,
          success: res.statusCode >= 200 && res.statusCode < 400,
        });
      });
    });

    req.on('error', (error) => {
      resolve({
        status: null,
        error: error.message,
        success: false,
      });
    });

    req.end();
  });
}

/**
 * Format test result
 */
function formatResult(service, endpoint, result) {
  const statusEmoji = result.success ? '✅' : '❌';
  const statusCode = result.status || 'N/A';
  const error = result.error ? ` (${result.error})` : '';

  console.log(`  ${statusEmoji} ${endpoint.padEnd(10)} - ${statusCode}${error}`);

  if (result.success && result.body) {
    try {
      const parsed = JSON.parse(result.body);
      if (parsed.status) {
        console.log(`     Status: ${parsed.status}`);
      }
      if (parsed.uptime) {
        console.log(`     Uptime: ${parsed.uptime.toFixed(2)}s`);
      }
    } catch (e) {
      // Not JSON, skip parsing
    }
  }
}

/**
 * Run tests
 */
async function runTests() {
  console.log('🏥 PistisAI Health Check Verification\n');
  console.log('Testing health check endpoints for all services...\n');

  let totalTests = 0;
  let passedTests = 0;

  for (const service of services) {
    console.log(`📦 ${service.name} (port ${service.port})`);

    for (const endpoint of service.endpoints) {
      totalTests++;
      const result = await testEndpoint('localhost', service.port, endpoint);

      if (result.success) {
        passedTests++;
      }

      formatResult(service, endpoint, result);
    }

    console.log();
  }

  // Summary
  console.log('━'.repeat(50));
  console.log(`\nResults: ${passedTests}/${totalTests} tests passed\n`);

  if (passedTests === totalTests) {
    console.log('✅ All health checks are working correctly!');
    process.exit(0);
  } else {
    console.log(`⚠️  ${totalTests - passedTests} test(s) failed. Services may not be running.`);
    process.exit(1);
  }
}

// Run with error handling
runTests().catch((error) => {
  console.error('Test execution failed:', error);
  process.exit(1);
});
