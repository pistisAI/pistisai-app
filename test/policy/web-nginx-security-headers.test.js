import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "@jest/globals";

describe("Web image nginx security headers (issue #850)", () => {
  const nginxPath = resolve(process.cwd(), "nginx.conf");
  const dockerfilePath = resolve(process.cwd(), "Dockerfile.web");
  const nginx = readFileSync(nginxPath, "utf8");
  const dockerfile = readFileSync(dockerfilePath, "utf8");

  it("copies repo-root nginx.conf into the web image", () => {
    expect(dockerfile).toMatch(
      /COPY\s+nginx\.conf\s+\/etc\/nginx\/conf\.d\/default\.conf/,
    );
  });

  it("sends anti-clickjacking and content-type security headers", () => {
    expect(nginx).toMatch(/add_header\s+X-Frame-Options\s+"DENY"\s+always/);
    expect(nginx).toMatch(
      /add_header\s+X-Content-Type-Options\s+"nosniff"\s+always/,
    );
    expect(nginx).toMatch(
      /add_header\s+Strict-Transport-Security\s+"max-age=\d+[^"]*"\s+always/,
    );
    expect(nginx).toMatch(
      /add_header\s+Content-Security-Policy\s+"[^"]*frame-ancestors\s+'none'[^"]*"\s+always/,
    );
  });

  it("re-declares security headers in every location that sets Cache-Control", () => {
    // nginx drops inherited add_header when a location defines its own.
    const locationBodies = [
      ...nginx.matchAll(/location[^{]*\{([^}]*)\}/g),
    ].map((m) => m[1]);

    const cacheLocations = locationBodies.filter((body) =>
      /add_header\s+Cache-Control/.test(body),
    );
    expect(cacheLocations.length).toBeGreaterThanOrEqual(3);

    for (const body of cacheLocations) {
      expect(body).toMatch(/add_header\s+X-Frame-Options\s+"DENY"\s+always/);
      expect(body).toMatch(
        /add_header\s+X-Content-Type-Options\s+"nosniff"\s+always/,
      );
      expect(body).toMatch(
        /add_header\s+Strict-Transport-Security\s+"max-age=\d+[^"]*"\s+always/,
      );
      expect(body).toMatch(
        /add_header\s+Content-Security-Policy\s+"[^"]*frame-ancestors\s+'none'[^"]*"\s+always/,
      );
    }
  });
});
