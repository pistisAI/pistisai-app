import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const tunnelServiceSource = fs.readFileSync(
  path.resolve(__dirname, "../../lib/services/tunnel_service.dart"),
  "utf8",
);

describe("legacy tunnel stats timer removal (#143)", () => {
  it("does not run a no-op stats collection timer", () => {
    expect(tunnelServiceSource).not.toMatch(/_statsTimer|statsTimer/);
    expect(tunnelServiceSource).not.toMatch(
      /Timer\.periodic\([^)]*\)\s*\{\s*\}/,
    );
  });

  it("keeps health monitoring on the active SSH tunnel client", () => {
    expect(tunnelServiceSource).toContain("_healthCheckTimer");
    expect(tunnelServiceSource).toContain("_startHealthMonitoring");
  });
});
