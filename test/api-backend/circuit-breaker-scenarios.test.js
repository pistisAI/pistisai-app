/**
 * Circuit Breaker Failure Scenario Tests
 *
 * Tests realistic failure scenarios including cascading failures,
 * network timeouts, and partial service degradation.
 */

import { CircuitBreaker, circuitBreakerManager, CIRCUIT_STATES } from '../../services/api-backend/middleware/circuit-breaker.js';

describe('Circuit Breaker - Failure Scenarios', () => {
  beforeEach(() => {
    circuitBreakerManager.resetAll();
  });

  test('should handle cascading failures from external service', async () => {
    const breaker = new CircuitBreaker({
      name: 'ollama',
      failureThreshold: 3,
      timeout: 100,
    });

    let failureCount = 0;
    let circuitOpenCount = 0;

    // Simulate 5 requests, 3 fail immediately opening circuit
    for (let i = 0; i < 5; i++) {
      if (!breaker.canProceed()) {
        circuitOpenCount++;
        continue;
      }
      breaker.recordFailure();
      failureCount++;
    }

    // First 3 should fail
    expect(failureCount).toBe(3);
    // Requests 4 and 5 should be blocked
    expect(circuitOpenCount).toBe(2);

    // Verify circuit is open
    expect(breaker.state).toBe(CIRCUIT_STATES.OPEN);
  });

  test('should recover when service becomes healthy again', async () => {
    const breaker = new CircuitBreaker({
      name: 'api-service',
      failureThreshold: 2,
      successThreshold: 1,
      timeout: 100,
    });

    // Simulate 2 failures that open the circuit
    breaker.recordFailure();
    breaker.recordFailure();
    expect(breaker.state).toBe(CIRCUIT_STATES.OPEN);

    // Immediately try - should be blocked
    expect(breaker.canProceed()).toBe(false);

    // Wait for recovery timeout
    await new Promise((resolve) => setTimeout(resolve, 150));

    // Should now transition to HALF_OPEN and allow request
    expect(breaker.canProceed()).toBe(true);
    expect(breaker.state).toBe(CIRCUIT_STATES.HALF_OPEN);

    // Record success - should transition to CLOSED after threshold
    breaker.recordSuccess();
    expect(breaker.state).toBe(CIRCUIT_STATES.CLOSED);
  });

  test('should reopen if failure occurs during recovery (HALF_OPEN)', async () => {
    const breaker = new CircuitBreaker({
      name: 'recovery-service',
      failureThreshold: 1,
      timeout: 100,
    });

    // Open the circuit
    breaker.recordFailure();
    expect(breaker.state).toBe(CIRCUIT_STATES.OPEN);

    // Wait for recovery
    await new Promise((resolve) => setTimeout(resolve, 150));

    // Transition to HALF_OPEN
    expect(breaker.canProceed()).toBe(true);
    expect(breaker.state).toBe(CIRCUIT_STATES.HALF_OPEN);

    // Fail during HALF_OPEN - should reopen
    breaker.recordFailure();
    expect(breaker.state).toBe(CIRCUIT_STATES.OPEN);
  });

  test('should handle partial service degradation', () => {
    const breaker = new CircuitBreaker({
      name: 'degraded-service',
      failureThreshold: 5,
      successThreshold: 2,
    });

    // Simulate mixed success/failure pattern
    let successCount = 0;
    let failureCount = 0;

    for (let i = 0; i < 10; i++) {
      if (i % 3 === 0) {
        // Every 3rd request fails
        if (breaker.canProceed()) {
          breaker.recordFailure();
          failureCount++;
        }
      } else {
        if (breaker.canProceed()) {
          breaker.recordSuccess();
          successCount++;
        }
      }
    }

    // Should handle degradation without opening circuit immediately
    expect(breaker.state).toBe(CIRCUIT_STATES.CLOSED);
    expect(failureCount).toBeGreaterThan(0);
    expect(successCount).toBeGreaterThan(failureCount);
  });

  test('should distinguish between success and circuit breaker failure', () => {
    const breaker = new CircuitBreaker({
      name: 'distinction-test',
      failureThreshold: 1,
    });

    // First request fails - opens circuit
    expect(breaker.canProceed()).toBe(true);
    breaker.recordFailure();
    expect(breaker.state).toBe(CIRCUIT_STATES.OPEN);

    // Second request immediately - circuit is open
    expect(breaker.canProceed()).toBe(false);

    // Both should fail but with different reasons
    // First: service error
    // Second: circuit breaker open
  });

  test('should reset to CLOSED from HALF_OPEN after success threshold', () => {
    const breaker = new CircuitBreaker({
      name: 'reset-test',
      failureThreshold: 1,
      successThreshold: 3,
      timeout: 50,
    });

    // Open the circuit
    breaker.recordFailure();
    expect(breaker.state).toBe(CIRCUIT_STATES.OPEN);

    // Artificially transition to HALF_OPEN for testing
    breaker.state = CIRCUIT_STATES.HALF_OPEN;
    breaker.successCount = 0;

    // Record successes until threshold
    breaker.recordSuccess(); // successCount = 1, HALF_OPEN
    expect(breaker.state).toBe(CIRCUIT_STATES.HALF_OPEN);

    breaker.recordSuccess(); // successCount = 2, HALF_OPEN
    expect(breaker.state).toBe(CIRCUIT_STATES.HALF_OPEN);

    breaker.recordSuccess(); // successCount = 3, close circuit
    expect(breaker.state).toBe(CIRCUIT_STATES.CLOSED);
    expect(breaker.successCount).toBe(0); // Reset on close
  });
});
