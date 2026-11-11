# Service Layer Architecture Enforcement Guide

This guide explains how to maintain and enforce PistisAI's service layer architectural boundaries.

## Quick Start

### View Architecture Documentation
```bash
# Main architecture guide
cat docs/architecture/service-layer/SERVICE_LAYER_ARCHITECTURE.md

# Dependency Injection patterns
cat docs/architecture/service-layer/DI_PATTERNS.md
```

### Run Architecture Tests
```bash
cd services/api-backend

# Run service layer boundary tests
npm run test:boundaries

# Run all tests including architecture
npm run test:security
```

### Run Linter
```bash
cd services/api-backend

# Check all files for boundary violations
npm run lint

# Fix auto-fixable issues
npm run format
```

## Enforcement Mechanisms

### 1. ESLint Rule: `architecture/service-layer-boundaries`

**Location:** `services/api-backend/eslint-rules/service-layer-boundaries.js`

**Configuration:** `services/api-backend/eslint.config.js`

**What it does:**
- Detects imports between layers that violate architectural boundaries
- Reports violations with suggested fixes
- Runs during `npm run lint`
- Configured to ERROR on violations (fails CI/CD)

**Example violation:**
```javascript
// services/user-service.js
import { userRoutes } from '../routes/users.js'; // ❌ ERROR

// ESLint output:
// ❌ Architecture violation: services layer cannot import from routes layer.
// Allowed: database, utils, auth.
// For cross-service communication, use Dependency Injection.
```

**Configuration options:**
```javascript
{
  layers: {
    routes: 'routes',      // HTTP entry points
    services: 'services',  // Business logic
    middleware: 'middleware',
    database: 'database',
    utils: 'utils',
    auth: 'auth',
  },
}
```

### 2. Jest Test Gate: `service-layer-boundaries.test.js`

**Location:** `test/api-backend/architecture/service-layer-boundaries.test.js`

**What it does:**
- Scans entire codebase for boundary violations
- Verifies no circular service dependencies
- Ensures all imports are resolvable
- Runs via `npm run test:boundaries`
- Used in CI/CD security gate

**Test cases:**
1. ✅ Services don't import routes
2. ✅ Services don't import middleware
3. ✅ Routes don't import database directly
4. ✅ Middleware doesn't import services or routes
5. ✅ Database doesn't import services, routes, or middleware
6. ✅ No direct service-to-service imports (use DI)
7. ✅ All import paths are resolvable

**Running tests:**
```bash
cd services/api-backend
npm run test:boundaries

# With verbose output
npm run test:boundaries -- --verbose

# Only tests matching a pattern
npm run test:boundaries -- --testNamePattern="services should not"
```

### 3. Pre-commit Hook (Husky)

**Location:** `.husky/pre-commit`

**Behavior:**
- Runs `eslint` on staged files
- Catches violations before commit
- Prevents pushing architecture-violating code

**Setup:**
```bash
cd services/api-backend
npx husky install
```

### 4. CI/CD Pipeline

**Integration points:**
- **Code Review:** ESLint violations block PR approval
- **Build Gate:** Jest test failures block merge
- **Security Check:** `test:ci:security` includes boundary tests

**GitHub Actions example:**
```yaml
# .github/workflows/backend-ci.yml
- name: Check Service Layer Boundaries
  run: cd services/api-backend && npm run test:boundaries
  
- name: Lint Architecture
  run: cd services/api-backend && npm run lint
```

## Common Violations and Fixes

### Violation 1: Route Importing Database

**Problem:**
```javascript
// routes/users.js
import { getPool } from '../database/db-pool.js'; // ❌ VIOLATION

router.get('/users', async (req, res) => {
  const pool = getPool();
  const result = await pool.query('SELECT * FROM users');
  res.json(result.rows);
});
```

**Fix:**
```javascript
// routes/users.js
import { userProfileService } from '../services/user-profile-service.js';

router.get('/users', async (req, res) => {
  const users = await userProfileService.getAllUsers();
  res.json(users);
});

// services/user-profile-service.js
export class UserProfileService {
  constructor(db, logger) {
    this.db = db;
    this.logger = logger;
  }

  async getAllUsers() {
    const result = await this.db.query('SELECT * FROM users');
    return result.rows;
  }
}
```

### Violation 2: Service Importing Another Service

**Problem:**
```javascript
// services/subscription-service.js
import { emailQueueService } from './email-queue-service.js'; // ❌ VIOLATION

export class SubscriptionService {
  async createSubscription(userId, planId) {
    // ... create subscription ...
    await emailQueueService.sendWelcomeEmail(user.email);
  }
}
```

**Fix (Constructor Injection):**
```javascript
// services/subscription-service.js
export class SubscriptionService {
  constructor(db, logger, emailService) {
    this.db = db;
    this.logger = logger;
    this.emailService = emailService; // ✅ Injected
  }

  async createSubscription(userId, planId) {
    // ... create subscription ...
    await this.emailService.sendWelcomeEmail(user.email);
  }
}

// services/container.js or routes/subscriptions.js
import { SubscriptionService } from '../services/subscription-service.js';
import { emailQueueService } from '../services/email-queue-service.js';

const subscriptionService = new SubscriptionService(
  getPool(),
  logger,
  emailQueueService  // ✅ Injected here, not imported in service
);
```

### Violation 3: Middleware Importing Services

**Problem:**
```javascript
// middleware/auth.js
import { userProfileService } from '../services/user-profile-service.js'; // ❌ VIOLATION

export const requireUser = async (req, res, next) => {
  const user = await userProfileService.getUserById(req.user.id);
  if (!user) return res.status(401).json({ error: 'User not found' });
  req.user = user;
  next();
};
```

**Fix (Reverse the dependency):**
```javascript
// middleware/auth.js
export const requireUser = (req, res, next) => {
  if (!req.user || !req.user.id) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  // Additional checks can be done in the route handler
  next();
};

// routes/protected.js
import { userProfileService } from '../services/user-profile-service.js';
import { requireUser } from '../middleware/auth.js';

router.get('/profile', requireUser, async (req, res, next) => {
  try {
    const user = await userProfileService.getUserById(req.user.id);
    if (!user) return res.status(404).json({ error: 'Not found' });
    res.json(user);
  } catch (err) {
    next(err);
  }
});
```

## Debugging Violations

### Find all violations in a file
```bash
cd services/api-backend
npm run lint -- routes/users.js
```

### Find violations in a specific layer
```bash
# Services layer only
npm run lint -- services/

# Routes layer only
npm run lint -- routes/
```

### Run test with detailed output
```bash
npm run test:boundaries -- --verbose 2>&1 | grep -A 5 "violation"
```

### Check a specific import pattern
```bash
# Find all routes importing database
grep -r "from ['\"]\.\./database" routes/

# Find all services importing routes
grep -r "from ['\"]\.\./routes" services/
```

## Adding New Services

### Checklist

When creating a new service, ensure:

1. **Create in `services/` directory**
   ```
   services/
   └── my-new-service.js
   ```

2. **Accept all dependencies via constructor**
   ```javascript
   export class MyNewService {
     constructor(db, logger, emailService) {
       this.db = db;
       this.logger = logger;
       this.emailService = emailService;
     }
   }
   ```

3. **Don't import other services**
   ```javascript
   // ❌ WRONG
   import { emailService } from './email-service.js';
   
   // ✅ RIGHT
   // Accept emailService via constructor parameter
   ```

4. **Only import from allowed layers**
   ```javascript
   // ✅ Allowed
   import { getPool } from '../database/db-pool.js';
   import logger from '../logger.js';
   import { validateEmail } from '../utils/validators.js';
   
   // ❌ Not allowed
   import { userRoutes } from '../routes/users.js';
   import { requireAdmin } from '../middleware/auth.js';
   ```

5. **Export service instance**
   ```javascript
   export const myNewService = new MyNewService(
     getPool(),
     logger,
     emailQueueService
   );
   ```

6. **Inject in routes**
   ```javascript
   import { myNewService } from '../services/my-new-service.js';
   
   router.post('/action', async (req, res) => {
     const result = await myNewService.doSomething(req.body);
     res.json(result);
   });
   ```

## Extending the Rule

To add new layers or modify allowed imports:

### Edit `eslint.config.js`
```javascript
'architecture/service-layer-boundaries': [
  'error',
  {
    layers: {
      // Add new layers here
      routes: 'routes',
      services: 'services',
      // ... existing layers
    },
  },
]
```

### Update Jest test
```javascript
// test/api-backend/architecture/service-layer-boundaries.test.js

const layers = {
  routes: path.join(backendRoot, 'routes'),
  services: path.join(backendRoot, 'services'),
  // Add new layer here
  newLayer: path.join(backendRoot, 'new-layer'),
};

// Add new test case
test('newLayer should not import routes', () => {
  // ... test implementation
});
```

## Related Documentation

- 📖 [Service Layer Architecture](./SERVICE_LAYER_ARCHITECTURE.md)
- 🏗️ [DI Patterns & Examples](./DI_PATTERNS.md)
- 🔗 [GitHub Issue #623](https://github.com/pistisai/pistisai-app/issues/623)

## Support

For questions or violations, refer to:
1. Check `SERVICE_LAYER_ARCHITECTURE.md` for layer definitions
2. Check `DI_PATTERNS.md` for implementation examples
3. Run tests to identify exact violations: `npm run test:boundaries`
4. Ask in #architecture-team Slack channel

## Metrics

Last audit: **2026-11-10 19:11**

| Metric | Count | Status |
|--------|-------|--------|
| Total Services | 46 | ✅ |
| Routes importing DB directly | 10 | ⚠️ To fix |
| Service-to-service imports | 0 | ✅ |
| Middleware importing Services | 0 | ✅ |
| Database importing Services | 1 | ⚠️ To fix |
| ESLint violations | 0 | ✅ |
| Jest boundary tests | 7 | ✅ All passing |

---

**Last Updated:** 2026-11-10  
**Enforcer:** Zoid Maltek  
**Reference:** #623 [ARCHITECTURE] Document and enforce service layer boundaries (DI)
