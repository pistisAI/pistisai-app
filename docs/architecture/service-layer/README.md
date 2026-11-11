# Service Layer Architecture & Dependency Injection

This directory contains comprehensive documentation and enforcement mechanisms for PistisAI's service layer architecture.

## 📖 Documentation Files

### 1. **SERVICE_LAYER_ARCHITECTURE.md**
The complete architectural guide covering:
- Layer hierarchy and definitions
- Responsibilities of each layer
- Dependency injection patterns
- Current violation audit
- Testing strategies
- Quick reference tables

**Start here if you need to understand:**
- What each layer does
- Which imports are allowed
- How to structure new services
- Layer boundaries and constraints

### 2. **DI_PATTERNS.md**
Practical examples and patterns for Dependency Injection:
- Constructor injection (recommended)
- Factory functions
- IoC containers
- Method injection
- Higher-order functions for composition
- Testing with mocks

**Start here if you need to:**
- Implement a new service
- Refactor existing code
- Learn DI best practices
- See working code examples

### 3. **ENFORCEMENT_GUIDE.md**
How to use and extend the enforcement mechanisms:
- ESLint rule configuration
- Jest test gate usage
- Pre-commit hooks
- CI/CD integration
- Common violations and fixes
- Debugging tips

**Start here if you need to:**
- Run architecture checks
- Debug violations
- Add new layers to the architecture
- Integrate with CI/CD

### 4. **ARCHITECTURE_DIAGRAM.html**
Visual interactive diagram showing:
- Layer hierarchy
- Allowed dependencies
- Enforcement rules
- DI pattern examples

**Open this file in a browser to:**
- See the architecture visually
- Understand layer relationships
- Reference allowed import paths

## 🚀 Quick Start

### View the Architecture
```bash
# Open the visual diagram in your browser
open docs/architecture/service-layer/ARCHITECTURE_DIAGRAM.html

# Or read the markdown guide
cat docs/architecture/service-layer/SERVICE_LAYER_ARCHITECTURE.md
```

### Check for Violations
```bash
cd services/api-backend

# Run ESLint to find violations
npm run lint

# Run comprehensive test gate
npm run test:boundaries

# Fix auto-fixable issues
npm run format
```

### Create a New Service
1. Read `DI_PATTERNS.md` to understand patterns
2. Create service in `services/your-service.js`
3. Accept all dependencies via constructor
4. Export singleton instance
5. Use in routes, never imported by other services

## 🏗️ Layer Overview

```
┌─────────────────────────────────────────┐
│ Routes (Express handlers)               │ ← HTTP Entry Point
├─────────────────────────────────────────┤
│ Middleware (Auth, Validation)           │ ← Cross-cutting concerns
├─────────────────────────────────────────┤
│ Services (Business Logic) - DI here     │ ← NO cross-service imports
├─────────┬───────────────────────────────┤
│ Database│ Utils & Auth (Shared)         │ ← Foundation layers
└─────────┴───────────────────────────────┘
```

### Layer Rules

| From | Can Import | Cannot Import |
|------|-----------|---------------|
| **Routes** | Services, Middleware, Utils | Database, other Routes |
| **Services** | Database, Utils, Auth | Routes, Middleware, other Services |
| **Middleware** | Utils, Auth | Routes, Services, Database |
| **Database** | Utils | Everything else |

## 🎯 Architecture Principles

1. **Single Responsibility** — Each service does one thing
2. **Explicit Dependencies** — Inject via constructor, don't import
3. **No Circular Dependencies** — Services compose, never reference each other
4. **Encapsulation** — Routes use services, never directly access DB
5. **Testability** — Easy to mock dependencies for unit tests

## 📋 Checklist: Adding a New Service

- [ ] Create `services/my-service.js`
- [ ] Define class with constructor accepting dependencies
- [ ] Import only from: `database/`, `utils/`, `auth/`, external libs
- [ ] Export singleton instance with injected dependencies
- [ ] Import in routes or DI container, never in other services
- [ ] Add tests in `test/api-backend/services/my-service.test.js`
- [ ] Run `npm run lint` to verify no violations
- [ ] Run `npm run test:boundaries` to verify architecture

## ✅ Enforcement Mechanisms

### 1. ESLint Rule
**File:** `services/api-backend/eslint-rules/service-layer-boundaries.js`
**Configuration:** `services/api-backend/eslint.config.js`
**Trigger:** `npm run lint`

Detects and reports boundary violations with helpful suggestions.

### 2. Jest Test Gate
**File:** `test/api-backend/architecture/service-layer-boundaries.test.js`
**Trigger:** `npm run test:boundaries`

Comprehensive codebase scan for:
- Service-to-service imports
- Routes importing database directly
- Middleware importing services
- Circular dependencies
- Broken import paths

### 3. Pre-commit Hook
**File:** `.husky/pre-commit`
Runs ESLint before commits to catch violations early.

### 4. CI/CD Pipeline
Runs both ESLint and Jest tests on every PR.
Blocks merge if violations exist.

## 🔍 Common Violations

### ❌ Service Importing Another Service
```javascript
// WRONG
import { emailService } from './email-service.js';

// RIGHT - Use Dependency Injection
export class SubscriptionService {
  constructor(db, logger, emailService) {
    this.emailService = emailService;
  }
}
```

### ❌ Route Importing Database Directly
```javascript
// WRONG
import { getPool } from '../database/db-pool.js';

// RIGHT - Use a service
import { userService } from '../services/user-service.js';
```

### ❌ Middleware Importing Services
```javascript
// WRONG
import { userService } from '../services/user-service.js';

// RIGHT - Keep middleware focused on cross-cutting concerns
// Move business logic to route handler
```

## 📚 File Structure

```
docs/architecture/service-layer/
├── README.md (this file)
├── SERVICE_LAYER_ARCHITECTURE.md (complete guide)
├── DI_PATTERNS.md (implementation examples)
├── ENFORCEMENT_GUIDE.md (how to use tools)
├── ARCHITECTURE_DIAGRAM.html (visual diagram)
└── violations-audit.txt (last audit results)

services/api-backend/
├── eslint-rules/
│   └── service-layer-boundaries.js (ESLint custom rule)
├── eslint.config.js (includes custom rule)
└── package.json (includes test:boundaries script)

test/api-backend/
├── architecture/
│   └── service-layer-boundaries.test.js (Jest test gate)
└── ...other tests...
```

## 🔗 Integration Guide

### Adding to Your Project's CI/CD

**GitHub Actions:**
```yaml
- name: Check Architecture Boundaries
  run: cd services/api-backend && npm run test:boundaries

- name: Lint Code
  run: cd services/api-backend && npm run lint
```

**Pre-commit Hook:**
```bash
cd services/api-backend
npx husky install
```

## 📊 Current Status

**Last Audit:** 2026-11-10 19:11

| Metric | Value | Status |
|--------|-------|--------|
| Total Services | 46 | ✅ |
| Routes → Database | 10 violations | ⚠️ Needs fixes |
| Service-to-Service | 0 violations | ✅ |
| Middleware → Services | 0 violations | ✅ |
| Database → Services | 1 violation | ⚠️ Needs fix |
| ESLint Tests | All passing | ✅ |
| Jest Test Gate | All passing | ✅ |

## 🆘 Need Help?

### Common Questions

**Q: Can service A import service B?**
A: No. Instead, inject B into A via constructor or DI container.

**Q: Can routes import database directly?**
A: No. Create a service to encapsulate DB queries.

**Q: Can middleware import services?**
A: No. Keep middleware focused on cross-cutting concerns.

**Q: Which imports are always allowed?**
A: Utils, auth, and external libraries from any layer.

### Debugging

```bash
# Find all violations
npm run lint

# Find specific violations
npm run lint -- services/

# Run tests with verbose output
npm run test:boundaries -- --verbose

# Check specific file
npm run lint -- routes/users.js
```

### Getting More Information

1. **Read** `SERVICE_LAYER_ARCHITECTURE.md` for comprehensive guide
2. **Check** `DI_PATTERNS.md` for code examples
3. **Review** `ENFORCEMENT_GUIDE.md` for tool usage
4. **View** `ARCHITECTURE_DIAGRAM.html` visually
5. **Ask** in #architecture-team Slack channel

## 🤝 Contributing

When adding new services:

1. Follow DI patterns from `DI_PATTERNS.md`
2. Run `npm run lint` before committing
3. Run `npm run test:boundaries` before pushing
4. Add tests for your service
5. Update documentation if adding new layer types

## 📖 Additional Resources

- [Service Layer Architecture](SERVICE_LAYER_ARCHITECTURE.md)
- [Dependency Injection Patterns](DI_PATTERNS.md)
- [Enforcement Guide](ENFORCEMENT_GUIDE.md)
- [GitHub Issue #623](https://github.com/pistisai/pistisai-app/issues/623)

## 📝 License

Part of the PistisAI Project

---

**Last Updated:** 2026-11-10  
**Maintainer:** PistisAI Architecture Team  
**Reference Issue:** #623 - Document and enforce service layer boundaries (DI)
