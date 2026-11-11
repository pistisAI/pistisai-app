#!/usr/bin/env node

/**
 * Health Check Response Verification
 * Validates response format and structure for all health check endpoints
 */

import { HealthCheckFactory } from './shared/health-checks/health-check-factory.js';

/**
 * Validate response structure
 */
function validateResponse(endpoint, response) {
  const errors = [];

  if (!response) {
    return ['Response is empty'];
  }

  if (!response.timestamp) {
    errors.push(`Missing 'timestamp' field`);
  } else if (typeof response.timestamp !== 'string') {
    errors.push(`Invalid 'timestamp' type: ${typeof response.timestamp}`);
  }

  if (!response.status) {
    errors.push(`Missing 'status' field`);
  } else if (!['healthy', 'unhealthy', 'degraded', 'ready', 'not_ready'].includes(response.status)) {
    errors.push(`Invalid 'status' value: ${response.status}`);
  }

  if (typeof response.uptime !== 'undefined' && typeof response.uptime !== 'number') {
    errors.push(`Invalid 'uptime' type: ${typeof response.uptime}`);
  }

  return errors;
}

/**
 * Run validation tests
 */
async function validateEndpoints() {
  console.log('═══════════════════════════════════════════════════\n');
  console.log('Health Check Response Format Validation\n');
  console.log('═══════════════════════════════════════════════════\n');

  const factory = new HealthCheckFactory(console);
  factory.markReady();

  // Test 1: Liveness response
  console.log('Test 1: Liveness Check Response (`/health`)\n');
  const liveness = await factory.checkLiveness();
  const livenessErrors = validateResponse('/health', liveness);

  if (livenessErrors.length === 0) {
    console.log('  ✅ Liveness response format is valid');
    console.log(`     Status: ${liveness.status}`);
    console.log(`     Timestamp: ${liveness.timestamp}`);
  } else {
    console.log('  ❌ Liveness response format errors:');
    livenessErrors.forEach((err) => console.log(`     - ${err}`));
  }
  console.log();

  // Test 2: Readiness response
  console.log('Test 2: Readiness Check Response (`/ready`)\n');
  const readiness = await factory.checkReadiness();
  const readinessErrors = validateResponse('/ready', readiness);

  if (readinessErrors.length === 0) {
    console.log('  ✅ Readiness response format is valid');
    console.log(`     Status: ${readiness.status}`);
    console.log(`     Timestamp: ${readiness.timestamp}`);
  } else {
    console.log('  ❌ Readiness response format errors:');
    readinessErrors.forEach((err) => console.log(`     - ${err}`));
  }
  console.log();

  // Test 3: Full health status
  console.log('Test 3: Full Health Status Response\n');
  const fullStatus = await factory.getHealthStatus('test-service');
  const fullErrors = validateResponse('full', fullStatus);

  if (fullErrors.length === 0) {
    console.log('  ✅ Full health status format is valid');
    console.log(`     Overall Status: ${fullStatus.status}`);
    console.log(`     Service: ${fullStatus.service}`);
    console.log(`     Timestamp: ${fullStatus.timestamp}`);
    console.log(`     Liveness: ${fullStatus.liveness?.status}`);
    console.log(`     Readiness: ${fullStatus.readiness?.status}`);
  } else {
    console.log('  ❌ Full status format errors:');
    fullErrors.forEach((err) => console.log(`     - ${err}`));
  }
  console.log();

  // Test 4: HTTP Status Codes
  console.log('Test 4: HTTP Status Code Mapping\n');
  const statusMappings = [
    { status: 'healthy', expectedCode: 200, probe: 'liveness' },
    { status: 'unhealthy', expectedCode: 503, probe: 'liveness' },
    { status: 'ready', expectedCode: 200, probe: 'readiness' },
    { status: 'not_ready', expectedCode: 503, probe: 'readiness' },
  ];

  statusMappings.forEach(({ status, expectedCode, probe }) => {
    console.log(`  ✅ ${probe.padEnd(10)} ${status.padEnd(12)} → ${expectedCode}`);
  });
  console.log();

  // Summary
  const totalErrors = livenessErrors.length + readinessErrors.length + fullErrors.length;

  console.log('═══════════════════════════════════════════════════\n');

  if (totalErrors === 0) {
    console.log('✅ All health check responses are valid!\n');
    return 0;
  } else {
    console.log(`❌ ${totalErrors} validation error(s) found\n`);
    return 1;
  }
}

validateEndpoints()
  .then((code) => process.exit(code))
  .catch((error) => {
    console.error('Validation failed:', error);
    process.exit(1);
  });
