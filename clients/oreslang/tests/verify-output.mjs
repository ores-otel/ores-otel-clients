// Independent output oracle for a compiler-executed tests/health_smoke.ores.
// This program never executes Oreslang; consumers MUST supply captured guest stdout.
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

export const expected = Object.freeze([
  "https://otel.example/v1/health",
  "https://otel.example:443/v1/health",
  "true", "true", "false", "false", "false", "false",
  "false", "false", "false", "false", "empty", "false", "false", "false", "false",
]);

export function verifyGuestStdout(stdout) {
  if (typeof stdout !== "string") throw new TypeError("Guest stdout must be UTF-8 text");
  if (stdout.includes("\u0000") || stdout.includes("\u001b")) throw new Error("Binary/ANSI guest output rejected");
  const normalized = stdout.replace(/\r\n/g, "\n").replace(/\n$/, "");
  const actual = normalized.split("\n");
  if (actual.length !== expected.length) {
    throw new Error("Expected " + expected.length + " guest records, got " + actual.length);
  }
  for (let i = 0; i < expected.length; i++) {
    if (actual[i] !== expected[i]) {
      throw new Error("Guest mismatch at record " + (i + 1) + ": expected " +
        JSON.stringify(expected[i]) + ", got " + JSON.stringify(actual[i]));
    }
  }
  return true;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.length !== 3) {
    console.error("Usage: node verify-output.mjs <actual-guest-stdout-file>");
    process.exitCode = 2;
  } else {
    try {
      const contents = readFileSync(process.argv[2]);
      const decoded = new TextDecoder("utf-8", { fatal: true }).decode(contents);
      verifyGuestStdout(decoded);
      console.log("Verified " + expected.length + " exact Oreslang guest records");
    } catch (error) {
      console.error(error.message);
      process.exitCode = 1;
    }
  }
}
