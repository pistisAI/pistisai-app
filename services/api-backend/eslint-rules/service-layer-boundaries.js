/**
 * ESLint rule: service-layer-boundaries
 *
 * Enforces service layer architectural boundaries to prevent cross-layer imports.
 * Prevents violations such as:
 * - Services importing routes or middleware
 * - Routes importing database directly
 * - Database importing services
 * - Circular service dependencies
 */

import path from 'path';

export default {
  meta: {
    type: 'problem',
    docs: {
      description: 'Enforce service layer architectural boundaries',
      category: 'Architecture',
      recommended: true,
    },
    schema: [
      {
        type: 'object',
        properties: {
          layers: {
            type: 'object',
            description: 'Directory names and their layer names',
            default: {
              routes: 'routes',
              services: 'services',
              middleware: 'middleware',
              database: 'database',
              utils: 'utils',
              auth: 'auth',
            },
          },
        },
        additionalProperties: false,
      },
    ],
  },

  create(context) {
    const options = context.options[0] || {};
    const { layers = {} } = options;

    // Get filename from context (flat config format)
    const filePath = context.filename || '';

    function detectLayer(fpath, layersConfig) {
      for (const [name, dirname] of Object.entries(layersConfig)) {
        // Check if file is in this layer's directory
        if (fpath.includes(`/${dirname}/`)) {
          return name;
        }
      }
      return null;
    }

    const sourceLayer = detectLayer(filePath, layers);

    // Only check files that are clearly in a layer (not root-level files or tests)
    if (!sourceLayer) {
      return {};
    }

    // Define allowed imports per layer
    const allowedImports = {
      routes: ['services', 'middleware', 'utils', 'auth'],
      services: ['database', 'utils', 'auth'],
      middleware: ['utils', 'auth'],
      database: ['utils'],
      utils: ['utils'],
      auth: ['utils', 'auth'],
    };

    function getTargetLayer(importPath, currentDir) {
      // Resolve relative path
      const resolved = path.resolve(currentDir, importPath);
      return detectLayer(resolved, layers);
    }

    return {
      ImportDeclaration(node) {
        const importValue = node.source.value;

        // Skip external imports (node_modules, @-scoped, absolute)
        if (!importValue.startsWith('.') && !importValue.startsWith('..')) {
          return;
        }

        const currentDir = path.dirname(filePath);
        const targetLayer = getTargetLayer(importValue, currentDir);

        if (!targetLayer) {
          return; // Target is not a recognized layer
        }

        // Check if import is allowed
        const allowed = allowedImports[sourceLayer] || [];
        if (!allowed.includes(targetLayer)) {
          // Special case: services importing services is never allowed
          if (sourceLayer === 'services' && targetLayer === 'services') {
            context.report({
              node,
              message: `❌ Architecture violation: services cannot import other services. ` +
                `Use Dependency Injection instead: inject via constructor.`,
            });
          } else {
            context.report({
              node,
              message: `❌ Architecture violation: ${sourceLayer} layer cannot import from ${targetLayer} layer. ` +
                `Allowed: ${allowed.join(', ')}`,
            });
          }
        }
      },
    };
  },
};
