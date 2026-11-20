import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "@jest/globals";

describe("GitHub Actions SHA pins (issue #850)", () => {
  const workflowPath = resolve(
    process.cwd(),
    ".github/workflows/auto-version-bump.yml",
  );
  const workflow = readFileSync(workflowPath, "utf8");

  it("pins actions/create-github-app-token to a full commit SHA", () => {
    const match = workflow.match(
      /uses:\s*actions\/create-github-app-token@([^\s#]+)/,
    );
    expect(match).not.toBeNull();
    expect(match[1]).toMatch(/^[0-9a-f]{40}$/);
  });
});
