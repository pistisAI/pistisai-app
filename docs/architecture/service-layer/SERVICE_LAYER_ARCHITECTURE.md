# Service Layer Architecture & Dependency Injection

## Overview

The PistisAI API Backend follows a **strict layered architecture** with clear dependency injection patterns. This document defines the service boundaries, allowed dependencies, and enforcement mechanisms to maintain architectural integrity.

## Layer Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│  HTTP/WebSocket Entry Points                                    │
│  (Express Routes: routes/*.js)                                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼ (DEPENDS ON)
┌─────────────────────────────────────────────────────────────────┐
│  Middleware Layer                                               │
│  (Auth, Validation, Error Handlers: middleware/*.js)           │
│                                                                  │
│  • Authentication & Authorization (auth.js)                    │
│  • Request Validation (schema-validation.js)                   │
│  • Error Handling (error-handler.js)                           │
│  • Rate Limiting (rate-limit.js)                               │
│  • Admin Auth (admin-auth.js)                                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼ (DEPENDS ON)
┌─────────────────────────────────────────────────────────────────┐
│  Service Layer (Business Logic)                                 │
│  (services/*.js) — DEPENDENCY INJECTION HERE                    │
│                                                                  │
│  • Domain Services (tunnel-service.js)                         │
│  • Integration Services (email-queue-service.js)               │
│  • Utility Services (metrics-service.js)                       │
│  • Cross-Cutting Services (error-recovery.js)                  │
│                                                                  │
│  [NO inter-service imports; compose via DI containers]         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                ┌──────────┴──────────┐
                ▼                     ▼
┌──────────────────────────┐  ┌─────────────────────────┐
│  Data Access             │  │  Supporting Layers      │
│  (database/*.js)         │  │  (utils/, auth/)        │
│                          │  │                         │
│  • Connection Pools      │  │  • Helpers              │
│  • Query Builders        │  │  • Validators           │
│  • Migrations            │  │  • Constants            │
│  • Seeds                 │  │  • Adapters             │
└──────────────────────────┘  └─────────────────────────┘
```

## Layer Definitions

### 1. Routes Layer (`routes/`)

**Purpose:** HTTP request handling, parameter extraction, response formatting.

**Responsibilities:**
- Receive HTTP requests
- Extract and normalize request data
- Call appropriate services
- Format and send responses
- Handle route-level concerns (versioning, deprecation)

**Allowed Dependencies:**
- ✅ Services
- ✅ Middleware (auth, validation)
- ✅ Utils
- ✅ Root-level utilities (logger.js)

**Prohibited Dependencies:**
- ❌ Database (direct access)
- ❌ Other routes
- ❌ Directly from models/middleware internals

**Example:**
```javascript
// routes/users.js
import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import { userProfileService } from '../services/user-profile-service.js';
import logger from '../logger.js';

const router = express.Router();

router.get('/:userId', authenticateJWT, async (req, res, next) => {
  try {
    const user = await userProfileService.getUserById(req.params.userId);
    res.json(user);
  } catch (err) {
    next(err);
  }
});

export default router;
```

### 2. Middleware Layer (`middleware/`)

**Purpose:** Cross-cutting concerns applied to requests before/after service execution.

**Responsibilities:**
- JWT/OAuth validation
- Request schema validation
- Authorization checks
- Error handling
- Rate limiting
- Logging/tracing

**Allowed Dependencies:**
- ✅ Utils
- ✅ Auth
- ✅ Root-level utilities

**Prohibited Dependencies:**
- ❌ Services
- ❌ Routes
- ❌ Database

**Example:**
```javascript
// middleware/auth.js
import jwt from 'jsonwebtoken';
import { ADMIN_ROLES } from '../utils/constants.js';

export const authenticateJWT = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: 'No token' });
  }
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch (err) {
    res.status(403).json({ error: 'Invalid token' });
  }
};

export const requireAdmin = (req, res, next) => {
  if (!ADMIN_ROLES.includes(req.user.role)) {
    return res.status(403).json({ error: 'Insufficient permissions' });
  }
  next();
};
```

### 3. Service Layer (`services/`)

**Purpose:** Business logic, domain operations, orchestration of data access and external integrations.

**Characteristics:**
- **No cross-service imports** — services are composed via Dependency Injection, not by importing each other
- **Single responsibility** — each service focuses on one domain or concern
- **Stateless or minimal state** — services are instantiated or used as singletons injected into routes
- **Explicit dependencies** — service constructors/factory functions declare what they need

**Allowed Dependencies:**
- ✅ Database layer
- ✅ Utils
- ✅ Auth utilities
- ✅ External libraries (stripe, nodemailer, etc.)

**Prohibited Dependencies:**
- ❌ Routes
- ❌ Middleware
- ❌ Other services (compose via DI containers instead)

**Example (Good DI Pattern):**
```javascript
// services/subscription-service.js
import { getPool } from '../database/db-pool.js';
import { stripe } from './stripe-client.js';
import logger from '../logger.js';

export class SubscriptionService {
  constructor(pool, stripeClient, logger) {
    this.pool = pool;
    this.stripeClient = stripeClient;
    this.logger = logger;
  }

  async createSubscription(userId, planId) {
    // Get user from DB via injected pool
    const user = await this.pool.query(
      'SELECT * FROM users WHERE id = $1',
      [userId]
    );
    
    // Use injected stripe client
    const subscription = await this.stripeClient.subscriptions.create({
      customer: user.stripe_id,
      items: [{ price: planId }],
    });
    
    return subscription;
  }
}

// Instantiate with DI container
export const subscriptionService = new SubscriptionService(
  getPool(),
  stripe,
  logger
);
```

**Example (Anti-Pattern - Avoid):**
```javascript
// ❌ BAD: Service importing another service
import { emailQueueService } from './email-queue-service.js';

export class SubscriptionService {
  async createSubscription(userId, planId) {
    // ... create subscription ...
    
    // ❌ VIOLATION: Direct service-to-service import
    await emailQueueService.sendWelcomeEmail(user.email);
  }
}
```

**Correct Approach (Dependency Injection):**
```javascript
// ✅ GOOD: Service accepts dependency, routes compose
export class SubscriptionService {
  constructor(pool, stripeClient, logger, emailService) {
    this.emailService = emailService;
  }

  async createSubscription(userId, planId) {
    // ... create subscription ...
    
    // ✅ Uses injected dependency
    await this.emailService.sendWelcomeEmail(user.email);
  }
}

// Route instantiates with both services
import { subscriptionService } from '../services/subscription-service.js';
import { emailQueueService } from '../services/email-queue-service.js';

router.post('/:userId/subscriptions', async (req, res) => {
  const subService = new SubscriptionService(
    getPool(),
    stripe,
    logger,
    emailQueueService  // ✅ Injected here, not imported in service
  );
  const result = await subService.createSubscription(req.params.userId, req.body.planId);
  res.json(result);
});
```

### 4. Database Layer (`database/`)

**Purpose:** Data access, connection pooling, schema management.

**Responsibilities:**
- PostgreSQL connection pool
- Query execution
- Transaction management
- Database migrations
- Test database seeding

**Allowed Dependencies:**
- ✅ Utils (constants, helpers)
- ✅ External DB libraries (pg, pg-query-stream)

**Prohibited Dependencies:**
- ❌ Services
- ❌ Routes
- ❌ Middleware

**Example:**
```javascript
// database/db-pool.js
import pg from 'pg';

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

export const getPool = () => pool;

export const query = async (sql, values) => {
  const client = await pool.connect();
  try {
    return await client.query(sql, values);
  } finally {
    client.release();
  }
};
```

### 5. Supporting Layers (`utils/`, `auth/`)

**Purpose:** Shared utilities and helpers.

**Responsibilities:**
- Constants and enumerations
- Error types and formatting
- Validation functions
- Authentication helpers
- Type definitions

**Allowed Dependencies:**
- ✅ Other utils
- ✅ External libraries

**Prohibited Dependencies:**
- ❌ Routes
- ❌ Services
- ❌ Middleware
- ❌ Database

**Example:**
```javascript
// utils/constants.js
export const ADMIN_ROLES = ['super_admin', 'admin'];
export const USER_ROLES = ['user', 'premium_user'];
export const API_RATE_LIMITS = { default: 100, premium: 1000 };

// utils/errors.js
export class ValidationError extends Error {
  constructor(message, details) {
    super(message);
    this.code = 'VALIDATION_ERROR';
    this.details = details;
  }
}

export class NotFoundException extends Error {
  constructor(resource) {
    super(`${resource} not found`);
    this.code = 'NOT_FOUND';
  }
}
```

## Dependency Injection Patterns

### Pattern 1: Constructor Injection (Recommended)

```javascript
export class TunnelService {
  constructor(db, logger, stripeClient) {
    this.db = db;
    this.logger = logger;
    this.stripeClient = stripeClient;
  }

  async createTunnel(userId, config) {
    // Use injected dependencies
    const user = await this.db.query('SELECT * FROM users WHERE id = $1', [userId]);
    this.logger.info(`Creating tunnel for user ${userId}`);
    return { tunnel: 'created' };
  }
}
```

### Pattern 2: Factory Function

```javascript
export function createTunnelService(db, logger) {
  return {
    async createTunnel(userId, config) {
      const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);
      logger.info(`Creating tunnel for user ${userId}`);
      return { tunnel: 'created' };
    },
  };
}
```

### Pattern 3: Singleton with DI Container

```javascript
// services/container.js
import { TunnelService } from './tunnel-service.js';
import { EmailQueueService } from './email-queue-service.js';
import { getPool } from '../database/db-pool.js';
import logger from '../logger.js';

const db = getPool();

const services = {
  tunnel: new TunnelService(db, logger),
  email: new EmailQueueService(db, logger),
  // ... all services instantiated once with DI
};

// routes/tunnels.js
import { services } from '../services/container.js';

router.post('/', async (req, res) => {
  const tunnel = await services.tunnel.createTunnel(req.user.id, req.body);
  res.json(tunnel);
});
```

## Current Violations Identified

### 1. Routes importing Database (10 instances)
**Impact:** Bypasses business logic, creates tight coupling
**Locations:** `routes/auth.js`, `routes/conversations.js`, etc.
**Fix:** Move query logic to appropriate services

### 2. Database importing Services (1 instance)
**Impact:** Circular dependency risk, violates data access isolation
**Location:** Check database migration files
**Fix:** Remove service calls from database layer

### 3. Middleware importing Database (1 instance)
**Impact:** Middleware couples to data schema
**Location:** Likely in rate-limit or auth middleware
**Fix:** Pass pre-fetched data or status flags

## Enforcement Mechanisms

### 1. ESLint Plugin Rule (Recommended)
Add a custom ESLint rule to detect and prevent cross-layer imports:
- Configurable layer definitions
- Automatic detection of violated imports
- CI/CD gate integration

### 2. Jest Test Gate
Unit tests verify that:
- Services don't import routes or middleware
- Routes don't import database directly
- No circular dependencies exist

### 3. Pre-commit Hook (Husky)
Lint staged files before commit to catch violations early.

### 4. CI Pipeline Check
Full codebase scan on PR/push to ensure all violations are caught.

## Migration Path

1. **Phase 1:** Document violations (completed)
2. **Phase 2:** Create DI container for services
3. **Phase 3:** Refactor routes to use service container
4. **Phase 4:** Add ESLint enforcement
5. **Phase 5:** Add Jest test gate
6. **Phase 6:** Update CI pipeline

## Testing Service Layer Boundaries

```javascript
// test/architecture/service-layer-boundaries.test.js
describe('Service Layer Boundaries', () => {
  it('services should not import routes', () => {
    const servicesDir = './services';
    // Scan files, verify no ../routes imports
  });

  it('routes should not import database directly', () => {
    const routesDir = './routes';
    // Scan files, verify no ../database/db-pool imports (use services instead)
  });

  it('services should not have circular dependencies', () => {
    // Build dependency graph, verify acyclic
  });

  it('middleware should not import services', () => {
    const middlewareDir = './middleware';
    // Scan files, verify no ../services imports
  });
});
```

## Quick Reference: Allowed Imports

| From → To | Routes | Middleware | Services | Database | Utils |
|-----------|--------|-----------|----------|----------|-------|
| **Routes** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Middleware** | ❌ | ✅ | ❌ | ❌ | ✅ |
| **Services** | ❌ | ❌ | ⚠️ | ✅ | ✅ |
| **Database** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Utils** | ✅ | ✅ | ✅ | ✅ | ✅ |

*Note:* ⚠️ = Only via Dependency Injection, not direct imports

## See Also

- [`SERVICE_LAYER_EXAMPLES.md`](./SERVICE_LAYER_EXAMPLES.md) — Detailed code examples
- [`DI_PATTERNS.md`](./DI_PATTERNS.md) — Dependency injection patterns and best practices
- [GitHub Issue #623](https://github.com/pistisai/pistisai-app/issues/623) — Original architecture decision
