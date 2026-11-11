/**
 * Service Layer Boundaries Test
 * 
 * Enforces architectural constraints:
 * 1. Services don't import routes or middleware
 * 2. Routes don't import database directly
 * 3. No circular dependencies between services
 * 4. Middleware doesn't import services or routes
 * 5. Database doesn't import services, routes, or middleware
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(__dirname, '..');

describe('Service Layer Boundaries', () => {
  const layers = {
    routes: path.join(backendRoot, 'routes'),
    services: path.join(backendRoot, 'services'),
    middleware: path.join(backendRoot, 'middleware'),
    database: path.join(backendRoot, 'database'),
    utils: path.join(backendRoot, 'utils'),
    auth: path.join(backendRoot, 'auth'),
  };

  function getAllJsFiles(dir) {
    if (!fs.existsSync(dir)) return [];
    const files = [];
    const walk = (currentPath) => {
      fs.readdirSync(currentPath).forEach(file => {
        const fullPath = path.join(currentPath, file);
        if (file === 'node_modules' || file === '__tests__') return;
        if (fs.statSync(fullPath).isDirectory()) {
          walk(fullPath);
        } else if (file.endsWith('.js')) {
          files.push(fullPath);
        }
      });
    };
    walk(dir);
    return files;
  }

  function getLayerForFile(filePath) {
    for (const [layer, layerPath] of Object.entries(layers)) {
      if (filePath.startsWith(layerPath + path.sep) || filePath.startsWith(layerPath)) {
        return layer;
      }
    }
    return 'root';
  }

  function extractImports(filePath) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const imports = [];
    
    // Match: import ... from '../...'
    const importRegex = /^import\s+.*?\s+from\s+['"](\.\.?\/[^'"]+)['"]/gm;
    let match;
    while ((match = importRegex.exec(content)) !== null) {
      imports.push(match[1]);
    }
    
    // Match: require('...')
    const requireRegex = /require\s*\(\s*['"](\.\.?\/[^'"]+)['"]\s*\)/g;
    while ((match = requireRegex.exec(content)) !== null) {
      imports.push(match[1]);
    }
    
    return imports;
  }

  function resolveImportTarget(importPath, sourceDir) {
    const resolved = path.resolve(sourceDir, importPath);
    
    // Handle paths without extension
    if (fs.existsSync(resolved + '.js')) {
      return resolved + '.js';
    }
    if (fs.existsSync(resolved)) {
      return resolved;
    }
    if (fs.existsSync(path.join(resolved, 'index.js'))) {
      return path.join(resolved, 'index.js');
    }
    
    return resolved;
  }

  test('services should not import from routes', () => {
    const violations = [];
    const serviceFiles = getAllJsFiles(layers.services);
    
    serviceFiles.forEach(file => {
      const imports = extractImports(file);
      imports.forEach(imp => {
        if (imp.includes('../routes') || imp.includes('routes/')) {
          violations.push({
            file: path.relative(backendRoot, file),
            import: imp,
            reason: 'Services should not import routes (encapsulation violation)',
          });
        }
      });
    });
    
    expect(violations).toEqual([], () => 
      `Service layer violations:\n${violations.map(v => 
        `  ${v.file}: ${v.import}\n    ⚠️  ${v.reason}`
      ).join('\n')}`
    );
  });

  test('services should not import from middleware', () => {
    const violations = [];
    const serviceFiles = getAllJsFiles(layers.services);
    
    serviceFiles.forEach(file => {
      const imports = extractImports(file);
      imports.forEach(imp => {
        if (imp.includes('../middleware') || imp.includes('middleware/')) {
          violations.push({
            file: path.relative(backendRoot, file),
            import: imp,
            reason: 'Services should not import middleware (encapsulation violation)',
          });
        }
      });
    });
    
    expect(violations).toEqual([], () =>
      `Service layer violations:\n${violations.map(v =>
        `  ${v.file}: ${v.import}\n    ⚠️  ${v.reason}`
      ).join('\n')}`
    );
  });

  test('routes should not import database directly', () => {
    const violations = [];
    const routeFiles = getAllJsFiles(layers.routes);
    
    routeFiles.forEach(file => {
      const imports = extractImports(file);
      imports.forEach(imp => {
        // Allow importing services from database, but not database directly
        if ((imp.includes('../database/db-pool') || 
             imp.includes('../database/migrate') ||
             imp.includes('database/db-pool')) &&
            !imp.includes('services')) {
          violations.push({
            file: path.relative(backendRoot, file),
            import: imp,
            reason: 'Routes must use services, not database directly',
            fix: `Create a service for this query and import from ../services/`,
          });
        }
      });
    });
    
    expect(violations).toEqual([], () =>
      `Route layer violations:\n${violations.map(v =>
        `  ${v.file}: ${v.import}\n    ⚠️  ${v.reason}\n    💡 ${v.fix}`
      ).join('\n')}`
    );
  });

  test('middleware should not import services or routes', () => {
    const violations = [];
    const middlewareFiles = getAllJsFiles(layers.middleware);
    
    middlewareFiles.forEach(file => {
      const imports = extractImports(file);
      imports.forEach(imp => {
        if (imp.includes('../services') || 
            imp.includes('../routes') ||
            imp.includes('services/') ||
            imp.includes('routes/')) {
          violations.push({
            file: path.relative(backendRoot, file),
            import: imp,
            reason: `Middleware should not import ${imp.includes('services') ? 'services' : 'routes'} (dependency inversion)`,
          });
        }
      });
    });
    
    expect(violations).toEqual([], () =>
      `Middleware layer violations:\n${violations.map(v =>
        `  ${v.file}: ${v.import}\n    ⚠️  ${v.reason}`
      ).join('\n')}`
    );
  });

  test('database should not import services, routes, or middleware', () => {
    const violations = [];
    const dbFiles = getAllJsFiles(layers.database);
    
    dbFiles.forEach(file => {
      const imports = extractImports(file);
      imports.forEach(imp => {
        if (imp.includes('../services') ||
            imp.includes('../routes') ||
            imp.includes('../middleware') ||
            imp.includes('services/') ||
            imp.includes('routes/') ||
            imp.includes('middleware/')) {
          violations.push({
            file: path.relative(backendRoot, file),
            import: imp,
            reason: 'Database layer should not import higher layers (dependency inversion)',
          });
        }
      });
    });
    
    expect(violations).toEqual([], () =>
      `Database layer violations:\n${violations.map(v =>
        `  ${v.file}: ${v.import}\n    ⚠️  ${v.reason}`
      ).join('\n')}`
    );
  });

  test('no direct service-to-service imports (use DI instead)', () => {
    const violations = [];
    const serviceFiles = getAllJsFiles(layers.services);
    const serviceFileNames = new Set(serviceFiles.map(f => path.basename(f, '.js')));
    
    serviceFiles.forEach(file => {
      const imports = extractImports(file);
      const sourceService = path.basename(file, '.js');
      
      imports.forEach(imp => {
        // Check if importing another service file directly
        serviceFileNames.forEach(otherService => {
          if (otherService !== sourceService &&
              (imp.includes(`../${otherService}`) ||
               imp.includes(`../${otherService}.js`) ||
               imp.includes(otherService))) {
            violations.push({
              file: path.relative(backendRoot, file),
              import: imp,
              reason: `Service-to-service import detected. Use Dependency Injection instead.`,
              pattern: `${sourceService} -> ${otherService}`,
            });
          }
        });
      });
    });
    
    expect(violations).toEqual([], () =>
      `Service-to-service import violations (use DI):\n${violations.map(v =>
        `  ${v.file}\n    Importing: ${v.import}\n    ⚠️  ${v.reason}`
      ).join('\n')}`
    );
  });

  test('all import paths are resolvable', () => {
    const violations = [];
    const allFiles = [
      ...getAllJsFiles(layers.routes),
      ...getAllJsFiles(layers.services),
      ...getAllJsFiles(layers.middleware),
      ...getAllJsFiles(layers.database),
      ...getAllJsFiles(layers.utils),
      ...getAllJsFiles(layers.auth),
    ];
    
    allFiles.forEach(file => {
      const imports = extractImports(file);
      imports.forEach(imp => {
        // Skip external imports
        if (!imp.startsWith('../') && !imp.startsWith('./')) {
          return;
        }
        
        const resolved = resolveImportTarget(imp, path.dirname(file));
        if (!fs.existsSync(resolved)) {
          // Check if it's a node_modules package
          if (!imp.includes('node_modules')) {
            violations.push({
              file: path.relative(backendRoot, file),
              import: imp,
              reason: `Import path not found: ${resolved}`,
            });
          }
        }
      });
    });
    
    expect(violations).toEqual([], () =>
      `Unresolvable imports:\n${violations.map(v =>
        `  ${v.file}: ${v.import}\n    ⚠️  ${v.reason}`
      ).join('\n')}`
    );
  });

  test('summary: service layer architecture compliance', () => {
    const serviceFiles = getAllJsFiles(layers.services);
    const routeFiles = getAllJsFiles(layers.routes);
    const middlewareFiles = getAllJsFiles(layers.middleware);
    
    console.log(`
Service Layer Architecture Audit:
  ✅ Routes: ${routeFiles.length} files
  ✅ Services: ${serviceFiles.length} files  
  ✅ Middleware: ${middlewareFiles.length} files
  
All boundary violations have been checked above.
    `);
    
    expect(true).toBe(true);
  });
});
