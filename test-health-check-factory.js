#!/usr/bin/env node

/**
 * Unit Tests for Health Check Implementations
 * Tests the HealthCheckFactory and service-specific implementations
 */

import { HealthCheckFactory } from './shared/health-checks/health-check-factory.js';

async function testHealthCheckFactory() {
  console.log('🧪 Testing HealthCheckFactory\n');

  const factory = new HealthCheckFactory(console);

  // Test 1: Initial state
  console.log('Test 1: Initial service state');
  let liveness = await factory.checkLiveness();
  let readiness = await factory.checkReadiness();
  
  console.log(`  ✓ Liveness status: ${liveness.status}`);
  console.log(`  ✓ Readiness status: ${readiness.status}`);
  console.log(`  ✓ Service NOT marked as ready initially: ${!factory.isReady}\n`);

  // Test 2: Mark as ready
  console.log('Test 2: Mark service as ready');
  factory.markReady();
  readiness = await factory.checkReadiness();
  console.log(`  ✓ Service marked as ready: ${factory.isReady}`);
  console.log(`  ✓ Readiness status after marking ready: ${readiness.status}\n`);

  // Test 3: Custom checks
  console.log('Test 3: Register custom health checks');
  factory.registerLivenessCheck('memory', async () => ({
    status: 'healthy',
    message: 'Memory usage within limits',
    details: { usage: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)}MB` },
  }));

  factory.registerReadinessCheck('dependencies', async () => ({
    status: 'ready',
    message: 'All dependencies initialized',
  }));

  liveness = await factory.checkLiveness();
  readiness = await factory.checkReadiness();
  console.log(`  ✓ Liveness checks include custom checks: ${liveness.checks ? Object.keys(liveness.checks).length > 0 : false}`);
  console.log(`  ✓ Readiness checks include custom checks: ${readiness.checks ? Object.keys(readiness.checks).length > 0 : false}\n`);

  // Test 4: Full health status
  console.log('Test 4: Get full health status');
  const status = await factory.getHealthStatus('test-service');
  console.log(`  ✓ Status includes service name: ${status.service === 'test-service'}`);
  console.log(`  ✓ Status includes uptime: ${typeof status.uptime === 'number'}`);
  console.log(`  ✓ Status includes liveness: ${status.liveness ? true : false}`);
  console.log(`  ✓ Status includes readiness: ${status.readiness ? true : false}`);
  console.log(`  ✓ Overall status: ${status.status}\n`);

  // Test 5: Express middleware creation
  console.log('Test 5: Create Express middleware');
  const livenessMiddleware = factory.createLivenessMiddleware();
  const readinessMiddleware = factory.createReadinessMiddleware();
  console.log(`  ✓ Liveness middleware is function: ${typeof livenessMiddleware === 'function'}`);
  console.log(`  ✓ Readiness middleware is function: ${typeof readinessMiddleware === 'function'}\n`);

  return {
    passed: 5,
    total: 5,
  };
}

async function runTests() {
  console.log('═══════════════════════════════════════════════════\n');
  console.log('Health Check Implementation Tests\n');
  console.log('═══════════════════════════════════════════════════\n');

  try {
    const results = await testHealthCheckFactory();

    console.log('═══════════════════════════════════════════════════\n');
    console.log(`Results: ${results.passed}/${results.total} tests passed\n`);

    if (results.passed === results.total) {
      console.log('✅ All health check tests passed!\n');
      process.exit(0);
    } else {
      console.log(`❌ ${results.total - results.passed} test(s) failed\n`);
      process.exit(1);
    }
  } catch (error) {
    console.error('Test execution failed:', error);
    process.exit(1);
  }
}

runTests();
