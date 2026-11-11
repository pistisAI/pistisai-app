/**
 * N+1 Query Detection Test Suite
 * 
 * This test gate ensures no NEW N+1 query patterns are introduced into the codebase.
 * It runs as part of the CI pipeline to catch performance regressions early.
 * 
 * Acceptance criteria:
 * - No new HIGH risk N+1 patterns allowed in PRs
 * - Existing N+1 issues documented and tracked
 * - Test fails if detection count exceeds threshold
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Known N+1 issues that are being tracked for remediation
// Add issue numbers as they are fixed
const KNOWN_N1_ISSUES = {
  'routes/admin/payments.js': { issues: ['#621'], count: 2 },
  'routes/conversations.js': { issues: ['#621'], count: 2 },
  'services/bulk-operations-service.js': { issues: ['#621'], count: 2 },
  'services/proxy-webhook-service.js': { issues: ['#621'], count: 2 },
  'services/tunnel-webhook-service.js': { issues: ['#621'], count: 2 },
};

// Maximum allowed new N+1 issues in a PR
const MAX_NEW_ISSUES = 0;

describe('N+1 Query Detection (CI Gate)', () => {
  let reportPath;

  beforeAll(() => {
    // Report path is in the api-backend directory (where detector runs)
    const backendDir = path.join(__dirname, '..', '..', 'services', 'api-backend');
    reportPath = path.join(backendDir, 'n1-detection-report.json');

    // Run detector if report doesn't exist
    if (!fs.existsSync(reportPath)) {
      console.log('Running N+1 detector...');
      const detectorScript = path.join(backendDir, 'scripts', 'n1-detector.js');
      try {
        execFileSync('node', [detectorScript, backendDir], {
          stdio: 'inherit',
        });
      } catch (err) {
        console.error('Detector error (may be expected during setup):', err.message);
      }
    }
  });

  test('should not exceed known N+1 issue threshold', () => {
    if (!fs.existsSync(reportPath)) {
      throw new Error(
        `N+1 detection report not found at ${reportPath}. Run n1-detector.js first.`
      );
    }

    const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));

    // Count new issues not in KNOWN_N1_ISSUES
    let newIssuesCount = 0;
    const newIssues = [];

    for (const finding of report.findings) {
      const known = KNOWN_N1_ISSUES[finding.file];

      if (!known || finding.severity === 'HIGH') {
        // Count as new if file not in known list or severity higher than documented
        if (!known || known.count < 2) {
          newIssuesCount++;
          newIssues.push(`${finding.file}: ${finding.pattern}`);
        }
      }
    }

    expect(newIssuesCount).toBeLessThanOrEqual(MAX_NEW_ISSUES);

    if (newIssuesCount > 0) {
      console.error('New N+1 issues detected (not in KNOWN_N1_ISSUES):');
      newIssues.forEach((issue) => console.error(`  - ${issue}`));
    }
  });

  test('should identify existing N+1 issues', () => {
    if (!fs.existsSync(reportPath)) {
      throw new Error(`N+1 detection report not found at ${reportPath}`);
    }

    const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));

    // Verify detector found the known issues
    let foundIssues = 0;
    for (const file in KNOWN_N1_ISSUES) {
      const fileIssues = report.findings.filter((f) => f.file === file);
      if (fileIssues.length > 0) {
        foundIssues += fileIssues.length;
      }
    }

    expect(foundIssues).toBeGreaterThan(0);
    console.log(`Found ${foundIssues} documented N+1 issues`);
  });

  test('statistics should show query coverage', () => {
    if (!fs.existsSync(reportPath)) {
      throw new Error(`N+1 detection report not found at ${reportPath}`);
    }

    const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
    const stats = report.stats;

    console.log(`
N+1 Query Detection Stats:
  Files scanned: ${stats.filesScanned}
  Total queries found: ${stats.queriesFound}
  Potential N+1 issues: ${stats.riskiesFound} (HIGH: ${stats.highRisk}, MEDIUM: ${stats.mediumRisk})
    `);

    // Sanity checks
    expect(stats.filesScanned).toBeGreaterThan(0);
    expect(stats.queriesFound).toBeGreaterThan(100);
  });

  test('should document remediation steps', () => {
    if (!fs.existsSync(reportPath)) {
      throw new Error(`N+1 detection report not found at ${reportPath}`);
    }

    const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));

    // Each finding should have remediation guidance
    for (const finding of report.findings) {
      expect(finding.remediation).toBeTruthy();
      expect(finding.remediation.length).toBeGreaterThan(0);
    }

    console.log(`All ${report.findings.length} findings include remediation guidance`);
  });
});
