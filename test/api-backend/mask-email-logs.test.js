/**
 * Email addresses must not reach plain logs: admin auth, admin management
 * and the email queue log a masked form instead.
 */
import { describe, expect, it } from "@jest/globals";
import path from "path";
import { fileURLToPath } from "url";
import { readFileSync } from "fs";

import { maskEmail } from "../../services/api-backend/utils/mask-email.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const API_DIR = path.join(__dirname, "../../services/api-backend");

describe("maskEmail", () => {
  it.each([
    ["alice@example.com", "a***@example.com"],
    ["  bob.smith@mail.example.org ", "b***@mail.example.org"],
    ["x@example.com", "x***@example.com"],
  ])("masks %s", (input, expected) => {
    expect(maskEmail(input)).toBe(expected);
  });

  it.each(["not-an-email", "@example.com", "user@", "", 42, {}])(
    "fully masks %p",
    (input) => {
      expect(maskEmail(input)).toBe("***");
    },
  );

  it("passes null and undefined through", () => {
    expect(maskEmail(null)).toBeNull();
    expect(maskEmail(undefined)).toBeUndefined();
  });
});

/** Return the argument text of every logger.<level>( ... ) call in a file. */
function loggerCalls(source) {
  const calls = [];
  const re = /\blogger\.(?:info|warn|error|debug)\(/g;
  let match;
  while ((match = re.exec(source))) {
    let depth = 1;
    let i = match.index + match[0].length;
    while (depth > 0 && i < source.length) {
      if (source[i] === "(") depth += 1;
      if (source[i] === ")") depth -= 1;
      i += 1;
    }
    calls.push(source.slice(match.index, i));
  }
  return calls;
}

describe("no raw email in logger calls", () => {
  it.each([
    "middleware/admin-auth.js",
    "routes/admin/admins.js",
    "services/email-queue-service.js",
    "auth/auth-service.js",
  ])("%s masks every email it logs", (file) => {
    const source = readFileSync(path.join(API_DIR, file), "utf8");
    const calls = loggerCalls(source);
    expect(calls.length).toBeGreaterThan(0);
    for (const call of calls) {
      // Any property whose value is an email-bearing expression must go
      // through maskEmail().
      const raw = call.match(
        /(?:^|[\s{,])(?:email|recipientEmail|requestedBy|grantedBy|revokedBy)\s*(?:,|:(?!\s*maskEmail\()[^,}\n]*)/gm,
      );
      expect({ call, raw }).toEqual({ call, raw: null });
    }
  });

  it("does not put the recipient address in the invalid-email error", async () => {
    const { default: EmailQueueService } =
      await import("../../services/api-backend/services/email-queue-service.js");
    const service = new EmailQueueService(
      { query: async () => ({ rows: [] }) },
      {},
      {},
    );
    const attempt = service.queueEmail({
      userId: "u1",
      recipientEmail: "alice.private@invalid",
      subject: "s",
      htmlBody: "<p>x</p>",
    });
    await expect(attempt).rejects.toThrow(/Invalid recipient email/);
    await expect(attempt).rejects.not.toThrow(/alice\.private/);
  });
});
