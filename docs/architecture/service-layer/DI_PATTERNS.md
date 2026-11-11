# Dependency Injection Patterns

This document provides concrete patterns and examples for implementing Dependency Injection in the PistisAI API Backend.

## 1. Constructor Injection Pattern

**Best for:** Most services that need shared dependencies (DB, logger, external clients)

```javascript
// services/user-profile-service.js
export class UserProfileService {
  constructor(db, logger, emailService) {
    this.db = db;
    this.logger = logger;
    this.emailService = emailService;
  }

  async getUserById(userId) {
    this.logger.debug(`Fetching user ${userId}`);
    const result = await this.db.query(
      'SELECT id, email, name FROM users WHERE id = $1',
      [userId]
    );
    return result.rows[0];
  }

  async updateProfile(userId, updates) {
    const user = await this.getUserById(userId);
    if (!user) throw new Error('User not found');

    await this.db.query(
      'UPDATE users SET name = $1, updated_at = NOW() WHERE id = $2',
      [updates.name, userId]
    );

    // Use injected email service
    await this.emailService.sendProfileUpdateEmail(user.email);
  }
}

// Instantiation
import { getPool } from '../database/db-pool.js';
import logger from '../logger.js';
import { emailQueueService } from './email-queue-service.js';

export const userProfileService = new UserProfileService(
  getPool(),
  logger,
  emailQueueService
);
```

**Usage in routes:**
```javascript
// routes/users.js
import { userProfileService } from '../services/user-profile-service.js';

router.get('/:userId', async (req, res, next) => {
  try {
    const user = await userProfileService.getUserById(req.params.userId);
    if (!user) return res.status(404).json({ error: 'Not found' });
    res.json(user);
  } catch (err) {
    next(err);
  }
});

router.put('/:userId', async (req, res, next) => {
  try {
    await userProfileService.updateProfile(req.params.userId, req.body);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});
```

## 2. Factory Function Pattern

**Best for:** Services that need complex setup or conditional initialization

```javascript
// services/cache-service.js
export function createCacheService(ttl = 300, maxSize = 1000) {
  const cache = new Map();

  return {
    get(key) {
      const entry = cache.get(key);
      if (!entry) return null;
      if (Date.now() > entry.expiresAt) {
        cache.delete(key);
        return null;
      }
      return entry.value;
    },

    set(key, value) {
      if (cache.size >= maxSize) {
        // Evict oldest entry
        const firstKey = cache.keys().next().value;
        cache.delete(firstKey);
      }
      cache.set(key, {
        value,
        expiresAt: Date.now() + ttl * 1000,
      });
    },

    clear() {
      cache.clear();
    },
  };
}

// services/container.js
export const cacheService = createCacheService(
  process.env.CACHE_TTL || 300,
  process.env.CACHE_MAX_SIZE || 1000
);
```

## 3. IoC Container Pattern

**Best for:** Large applications with many services and complex dependency graphs

```javascript
// services/container.js
import { UserProfileService } from './user-profile-service.js';
import { SubscriptionService } from './subscription-service.js';
import { EmailQueueService } from './email-queue-service.js';
import { TunnelService } from './tunnel-service.js';
import { getPool } from '../database/db-pool.js';
import logger from '../logger.js';
import { stripe } from './stripe-client.js';

export class ServiceContainer {
  constructor() {
    this.db = getPool();
    this.logger = logger;
    this.cache = new Map(); // Service instance cache
  }

  /**
   * Register a service factory or instance
   * @param {string} name - Service name
   * @param {Function|Object} definition - Factory function or instance
   */
  register(name, definition) {
    this.cache.set(name, definition);
  }

  /**
   * Get or create a service instance
   * @param {string} name - Service name
   * @returns {*} Service instance
   */
  get(name) {
    const definition = this.cache.get(name);
    if (!definition) throw new Error(`Service '${name}' not registered`);
    
    // If it's a factory function, call it
    if (typeof definition === 'function') {
      return definition(this);
    }
    // Otherwise return the instance as-is
    return definition;
  }
}

// Create singleton container
const container = new ServiceContainer();

// Register services with their dependencies
container.register('emailQueue', (c) => 
  new EmailQueueService(c.db, c.logger)
);

container.register('userProfile', (c) =>
  new UserProfileService(c.db, c.logger, c.get('emailQueue'))
);

container.register('subscription', (c) =>
  new SubscriptionService(c.db, c.logger, stripe, c.get('emailQueue'))
);

container.register('tunnel', (c) =>
  new TunnelService(c.db, c.logger)
);

export default container;
```

**Usage in routes:**
```javascript
// routes/subscriptions.js
import container from '../services/container.js';

const subscriptionService = container.get('subscription');

router.post('/:userId/subscriptions', async (req, res, next) => {
  try {
    const subscription = await subscriptionService.createSubscription(
      req.params.userId,
      req.body.planId
    );
    res.json(subscription);
  } catch (err) {
    next(err);
  }
});
```

## 4. Module Exports Pattern (Simple)

**Best for:** Simple applications or individual service files

```javascript
// services/metrics-service.js
import { getPool } from '../database/db-pool.js';
import logger from '../logger.js';

class MetricsService {
  constructor(db, logger) {
    this.db = db;
    this.logger = logger;
  }

  async recordMetric(eventName, value, tags = {}) {
    this.logger.debug(`Recording metric: ${eventName} = ${value}`);
    await this.db.query(
      'INSERT INTO metrics (event, value, tags, created_at) VALUES ($1, $2, $3, NOW())',
      [eventName, value, JSON.stringify(tags)]
    );
  }

  async getMetrics(eventName, limit = 100) {
    const result = await this.db.query(
      'SELECT * FROM metrics WHERE event = $1 ORDER BY created_at DESC LIMIT $2',
      [eventName, limit]
    );
    return result.rows;
  }
}

// Export singleton instance
export const metricsService = new MetricsService(getPool(), logger);
```

## 5. Method Injection Pattern

**Best for:** Services that have optional dependencies or late-binding

```javascript
// services/error-notification-service.js
export class ErrorNotificationService {
  constructor(logger) {
    this.logger = logger;
  }

  /**
   * Notify about an error using the provided notifier
   * @param {Object} notifier - Email or Slack notifier instance
   * @param {Error} error - Error to notify
   */
  async notifyError(notifier, error) {
    this.logger.error(`Notifying error via ${notifier.constructor.name}`, error);
    
    // Different notifiers handle differently
    if (notifier.sendEmail) {
      await notifier.sendEmail({
        to: 'admin@pistisai.app',
        subject: 'Production Error',
        body: error.message,
      });
    } else if (notifier.postToChannel) {
      await notifier.postToChannel('errors', `Error: ${error.message}`);
    }
  }
}

// Usage
import { errorNotificationService } from '../services/error-notification-service.js';
import { emailService } from '../services/email-queue-service.js';
import { slackService } from '../services/slack-service.js';

try {
  // Do something
} catch (error) {
  // Inject different notifiers based on severity
  if (error.severity === 'critical') {
    await errorNotificationService.notifyError(emailService, error);
    await errorNotificationService.notifyError(slackService, error);
  }
}
```

## 6. Composition with Higher-Order Functions

**Best for:** Adding behavior dynamically (logging, caching, retries)

```javascript
// services/decorators.js
export function withLogging(service, logger) {
  return new Proxy(service, {
    async apply(target, thisArg, args) {
      logger.info(`Calling ${target.name} with args`, args);
      const result = await target.apply(thisArg, args);
      logger.info(`${target.name} returned`, result);
      return result;
    },
  });
}

export function withRetry(fn, maxAttempts = 3, delay = 100) {
  return async (...args) => {
    let lastError;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn(...args);
      } catch (error) {
        lastError = error;
        if (attempt < maxAttempts) {
          await new Promise(resolve => setTimeout(resolve, delay * attempt));
        }
      }
    }
    throw lastError;
  };
}

export function withCaching(fn, cache, ttl = 300) {
  return async (...args) => {
    const key = JSON.stringify(args);
    const cached = cache.get(key);
    if (cached) return cached;

    const result = await fn(...args);
    cache.set(key, result);
    setTimeout(() => cache.delete(key), ttl * 1000);
    return result;
  };
}

// Usage
import { withRetry, withCaching } from '../services/decorators.js';

export class TunnelService {
  constructor(db, logger, cache) {
    this.db = db;
    this.logger = logger;
    this.cache = cache;
  }

  async getTunnelById(tunnelId) {
    // Without decorator
    const result = await this.db.query(
      'SELECT * FROM tunnels WHERE id = $1',
      [tunnelId]
    );
    return result.rows[0];
  }

  async createTunnelWithRetry(userId, config) {
    // With retry decorator
    const createFn = withRetry(
      () => this.db.query(
        'INSERT INTO tunnels (user_id, config) VALUES ($1, $2) RETURNING *',
        [userId, JSON.stringify(config)]
      ),
      3,
      100
    );
    
    return await createFn();
  }
}
```

## 7. Testing with Mocks/Stubs

**Best for:** Unit testing services in isolation

```javascript
// test/services/user-profile-service.test.js
import { UserProfileService } from '../../services/user-profile-service.js';

describe('UserProfileService', () => {
  let service, dbMock, loggerMock, emailServiceMock;

  beforeEach(() => {
    // Create mock dependencies
    dbMock = {
      query: jest.fn(),
    };

    loggerMock = {
      debug: jest.fn(),
      error: jest.fn(),
    };

    emailServiceMock = {
      sendProfileUpdateEmail: jest.fn(),
    };

    // Inject mocks into service
    service = new UserProfileService(dbMock, loggerMock, emailServiceMock);
  });

  test('getUserById should query database', async () => {
    const userId = '123';
    const mockUser = { id: userId, email: 'test@example.com', name: 'Test User' };

    dbMock.query.mockResolvedValue({ rows: [mockUser] });

    const result = await service.getUserById(userId);

    expect(dbMock.query).toHaveBeenCalledWith(
      'SELECT id, email, name FROM users WHERE id = $1',
      [userId]
    );
    expect(result).toEqual(mockUser);
  });

  test('updateProfile should send email via injected service', async () => {
    const userId = '123';
    const mockUser = { id: userId, email: 'test@example.com', name: 'Test User' };

    dbMock.query.mockResolvedValue({ rows: [mockUser] });

    await service.updateProfile(userId, { name: 'New Name' });

    expect(emailServiceMock.sendProfileUpdateEmail).toHaveBeenCalledWith(
      mockUser.email
    );
  });
});
```

## Best Practices

1. **Inject at construction time** - Avoid service-to-service imports
2. **Use named exports** - Make it clear what services are available
3. **Document dependencies** - List required and optional dependencies
4. **Test with mocks** - Verify behavior without real dependencies
5. **Keep services stateless** - Minimize instance variables
6. **Use a container** - For large applications with many services
7. **Avoid globals** - Use DI instead of process.env in business logic
8. **Single responsibility** - Each service has one reason to change
9. **Composition over inheritance** - Prefer function composition to class hierarchy
10. **Lazy initialization** - Only create services when needed (container.get())

## Anti-Patterns to Avoid

### ❌ Service-to-Service Import
```javascript
// BAD: Direct import
import { emailQueueService } from './email-queue-service.js';

export class SubscriptionService {
  async createSubscription(...) {
    await emailQueueService.send(...); // ❌ Violation
  }
}
```

### ❌ Globals in Services
```javascript
// BAD: Using process.env directly
export class StripeService {
  constructor() {
    this.apiKey = process.env.STRIPE_SECRET_KEY; // ❌ Tight coupling
  }
}
```

### ❌ Circular Dependencies
```javascript
// services/a.js
import { serviceB } from './b.js';
export const serviceA = new ServiceA(serviceB);

// services/b.js
import { serviceA } from './a.js';
export const serviceB = new ServiceB(serviceA); // ❌ Circular
```

### ❌ Mixing Concerns
```javascript
// BAD: Service handles HTTP and business logic
export class UserService {
  async handleUserRequest(req, res) { // ❌ Not a service concern
    // ...
  }
}
```

## Examples Repository Structure

```
services/
├── index.js              # Export all services and container
├── container.js          # IoC container definition
├── user-profile-service.js
├── subscription-service.js
├── email-queue-service.js
├── tunnel-service.js
├── stripe-client.js      # External client wrapper
├── decorators.js         # Service composition utilities
└── __tests__/
    ├── user-profile-service.test.js
    ├── subscription-service.test.js
    └── ...

routes/
├── index.js
├── users.js
├── subscriptions.js
└── ...

middleware/
├── auth.js
├── validation.js
├── error-handler.js
└── ...

database/
├── db-pool.js
├── migrations/
└── ...

utils/
├── constants.js
├── errors.js
└── validators.js
```

## See Also

- [`SERVICE_LAYER_ARCHITECTURE.md`](./SERVICE_LAYER_ARCHITECTURE.md) — Complete architecture overview
- [GitHub Issue #623](https://github.com/pistisai/pistisai-app/issues/623) — Architecture discussion
