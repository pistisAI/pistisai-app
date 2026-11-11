#!/usr/bin/env node

/**
 * N+1 Query Detector for api-backend
 *
 * Scans JavaScript files for potential N+1 query patterns:
 * - Queries inside loops without batching
 * - Queries in array.map() without Promise.all()
 * - Sequential queries instead of JOINs
 *
 * Output: JSON report with findings, risk levels, and remediation advice
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Risk patterns to detect
const N1_PATTERNS = [
  {
    name: 'Loop Query',
    regex: /(?:for|while)\s*\([^)]*\)\s*\{[^}]*(?:pool\.query|client\.query|db\.query|query\()/s,
    severity: 'HIGH',
    description: 'Query inside a for/while loop without batching',
  },
  {
    name: 'Map Query',
    regex: /\.map\s*\([^)]*\)\s*\{[^}]*(?:await\s+)?(?:pool\.query|client\.query|db\.query|query\()/s,
    severity: 'HIGH',
    description: 'Query inside array.map() without Promise.all()',
  },
  {
    name: 'Sequential Awaits in Loop',
    regex: /for(?:Each)?\s*\([^)]*\)\s*\{[^}]*await\s+(?:pool\.query|client\.query|db\.query|query\()/s,
    severity: 'HIGH',
    description: 'Sequential await in forEach - not concurrent',
  },
  {
    name: 'Query After Query',
    regex: /await\s+(?:pool|client|db)?\.query\([^)]+\)[^;]*;\s*(?:const|let|var)\s+\w+\s*=\s*await\s+(?:pool|client|db)?\.query\(/,
    severity: 'MEDIUM',
    description: 'Sequential queries that could use JOIN',
  },
  {
    name: 'Nested Query Await',
    regex: /await\s+(?:pool|client|db)?\.query\s*\([^)]*await\s+(?:pool|client|db)?\.query/s,
    severity: 'MEDIUM',
    description: 'Query result used to perform another query',
  },
];

// Whitelist patterns (known safe patterns)
const SAFE_PATTERNS = [
  /Promise\.all\s*\([^)]*\.map/s, // Promise.all with map
  /const\s+results\s*=\s*await\s+Promise\.all/s, // Batched queries
  /IN\s*\(\$\d+\)/s, // PostgreSQL IN clause for bulk
];

class N1Detector {
  constructor(rootDir) {
    this.rootDir = rootDir;
    this.findings = [];
    this.stats = {
      filesScanned: 0,
      queriesFound: 0,
      riskiesFound: 0,
      highRisk: 0,
      mediumRisk: 0,
    };
  }

  async scan() {
    const dirs = ['routes', 'services'];

    for (const dir of dirs) {
      const fullPath = path.join(this.rootDir, dir);
      if (fs.existsSync(fullPath)) {
        await this.scanDirectory(fullPath);
      }
    }

    return this.generateReport();
  }

  async scanDirectory(dir) {
    const files = fs.readdirSync(dir, { withFileTypes: true });

    for (const file of files) {
      const fullPath = path.join(dir, file.name);

      if (file.isDirectory()) {
        await this.scanDirectory(fullPath);
      } else if (file.name.endsWith('.js')) {
        this.scanFile(fullPath);
      }
    }
  }

  scanFile(filePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const relativePath = path.relative(this.rootDir, filePath);

      this.stats.filesScanned++;

      // Count queries
      const queryMatches = content.match(/(?:pool|client|db)?\.query\(/g) || [];
      this.stats.queriesFound += queryMatches.length;

      // Check for N+1 patterns
      this.checkPatterns(content, relativePath);
    } catch (err) {
      console.error(`Error scanning ${filePath}:`, err.message);
    }
  }

  checkPatterns(content, filePath) {
    // Check safe patterns first (whitelist)
    for (const safePattern of SAFE_PATTERNS) {
      if (safePattern.test(content)) {
        return; // This file has safe patterns, likely OK
      }
    }

    // Check N+1 patterns
    for (const pattern of N1_PATTERNS) {
      if (pattern.regex.test(content)) {
        this.stats.riskiesFound++;

        if (pattern.severity === 'HIGH') {
          this.stats.highRisk++;
        } else {
          this.stats.mediumRisk++;
        }

        this.findings.push({
          file: filePath,
          pattern: pattern.name,
          severity: pattern.severity,
          description: pattern.description,
          remediation: this.getRemediation(pattern.name),
        });
      }
    }
  }

  getRemediation(patternName) {
    const remediations = {
      'Loop Query':
        'Use Promise.all() to batch queries or refactor to use JOIN with IN clause',
      'Map Query':
        'Wrap map() result with Promise.all() or use database JOIN',
      'Sequential Awaits in Loop':
        'Use Promise.all(array.map(item => pool.query(...)))',
      'Query After Query':
        'Combine queries using SQL JOIN instead of two separate queries',
      'Nested Query Await':
        'Fetch all related data in first query or batch the second query',
    };
    return remediations[patternName] || 'Refactor to use batching or JOINs';
  }

  generateReport() {
    return {
      timestamp: new Date().toISOString(),
      rootDir: this.rootDir,
      stats: this.stats,
      findings: this.findings,
      summary: {
        passed: this.stats.riskiesFound === 0,
        message:
          this.stats.riskiesFound === 0
            ? 'No N+1 query patterns detected'
            : `Detected ${this.stats.riskiesFound} potential N+1 issues (${this.stats.highRisk} HIGH, ${this.stats.mediumRisk} MEDIUM)`,
      },
    };
  }
}

// Main execution
async function main() {
  const rootDir =
    process.argv[2] || path.join(__dirname, '../services/api-backend');
  const detector = new N1Detector(rootDir);

  console.log(`Scanning for N+1 queries in: ${rootDir}\n`);

  const report = await detector.scan();

  // Write report to file
  const reportPath = path.join(rootDir, 'n1-detection-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

  // Console output
  console.log(`✓ Scanned ${report.stats.filesScanned} files`);
  console.log(`✓ Found ${report.stats.queriesFound} SQL queries`);
  console.log(
    `✗ Detected ${report.stats.riskiesFound} potential N+1 issues`
  );
  console.log(
    `  - HIGH: ${report.stats.highRisk}, MEDIUM: ${report.stats.mediumRisk}`
  );
  console.log(`\nDetailed report: ${reportPath}\n`);

  if (report.findings.length > 0) {
    console.log('Top findings:');
    report.findings.slice(0, 10).forEach((finding, idx) => {
      console.log(
        `  ${idx + 1}. [${finding.severity}] ${finding.file} - ${finding.pattern}`
      );
      console.log(`     → ${finding.description}`);
      console.log(`     ↳ ${finding.remediation}\n`);
    });

    if (report.findings.length > 10) {
      console.log(
        `  ... and ${report.findings.length - 10} more findings in report\n`
      );
    }
  }

  process.exit(report.summary.passed ? 0 : 1);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
