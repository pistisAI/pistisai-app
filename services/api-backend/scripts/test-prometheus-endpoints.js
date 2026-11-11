#!/usr/bin/env node
/**
 * @fileoverview Test script to verify Prometheus metrics endpoints
 * Tests connectivity and metric collection for all monitored services
 */

import http from 'http';
import https from 'https';

const services = [
  {
    name: 'API Backend',
    url: 'http://api-backend:8080/prometheus/metrics',
    healthUrl: 'http://api-backend:8080/prometheus/health/metrics',
  },
  {
    name: 'Streaming Proxy',
    url: 'http://streaming-proxy:3001/metrics',
  },
];

/**
 * Test endpoint connectivity
 * @param {string} url - URL to test
 * @returns {Promise<Object>} Test result
 */
async function testEndpoint(url) {
  return new Promise((resolve) => {
    const protocol = url.startsWith('https') ? https : http;
    const timeoutId = setTimeout(() => {
      resolve({
        success: false,
        status: null,
        error: 'Timeout',
        metricsCount: 0,
      });
    }, 5000);

    protocol
      .get(url, (res) => {
        clearTimeout(timeoutId);
        let data = '';

        res.on('data', (chunk) => {
          data += chunk;
        });

        res.on('end', () => {
          try {
            // Count metric lines (non-empty, non-comment lines starting with lowercase)
            const metricLines = data
              .split('\n')
              .filter(
                (line) =>
                  line.trim() &&
                  !line.startsWith('#') &&
                  /^[a-z_]/.test(line),
              );

            resolve({
              success: res.statusCode === 200,
              status: res.statusCode,
              contentType: res.headers['content-type'],
              metricsCount: metricLines.length,
              sampleMetrics: metricLines.slice(0, 3),
              error: null,
            });
          } catch (error) {
            resolve({
              success: false,
              status: res.statusCode,
              error: error.message,
              metricsCount: 0,
            });
          }
        });
      })
      .on('error', (error) => {
        clearTimeout(timeoutId);
        resolve({
          success: false,
          status: null,
          error: error.message,
          metricsCount: 0,
        });
      });
  });
}

/**
 * Run all tests
 */
async function runTests() {
  console.log('🔍 Prometheus Metrics Endpoint Test\n');
  console.log('═'.repeat(80));

  let passedTests = 0;
  let totalTests = 0;

  for (const service of services) {
    console.log(`\n📊 Testing: ${service.name}`);
    console.log('─'.repeat(80));

    // Test main metrics endpoint
    totalTests += 1;
    console.log(`\n📈 Metrics Endpoint: ${service.url}`);
    const metricsResult = await testEndpoint(service.url);

    if (metricsResult.success) {
      console.log(`✅ Status: ${metricsResult.status}`);
      console.log(`📊 Metrics Found: ${metricsResult.metricsCount}`);
      console.log(`📝 Content-Type: ${metricsResult.contentType}`);
      if (metricsResult.sampleMetrics.length > 0) {
        console.log(`\n📋 Sample Metrics:`);
        metricsResult.sampleMetrics.forEach((metric, idx) => {
          const truncated = metric.substring(0, 100);
          console.log(`   ${idx + 1}. ${truncated}${metric.length > 100 ? '...' : ''}`);
        });
      }
      passedTests += 1;
    } else {
      console.log(`❌ Error: ${metricsResult.error}`);
      if (metricsResult.status) {
        console.log(`   HTTP Status: ${metricsResult.status}`);
      }
    }

    // Test health endpoint if available
    if (service.healthUrl) {
      totalTests += 1;
      console.log(`\n💚 Health Endpoint: ${service.healthUrl}`);
      const healthResult = await testEndpoint(service.healthUrl);

      if (healthResult.success) {
        console.log(`✅ Status: ${healthResult.status}`);
        console.log(`📊 Health Check OK`);
        passedTests += 1;
      } else {
        console.log(`❌ Error: ${healthResult.error}`);
      }
    }
  }

  // Summary
  console.log('\n' + '═'.repeat(80));
  console.log(`\n📊 Test Summary: ${passedTests}/${totalTests} passed`);

  if (passedTests === totalTests) {
    console.log('✅ All tests passed! Prometheus metrics are being collected.\n');
    process.exit(0);
  } else {
    console.log(
      '⚠️  Some tests failed. Check service connectivity and configuration.\n',
    );
    process.exit(1);
  }
}

runTests();
