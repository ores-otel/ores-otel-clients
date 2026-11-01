// Host-only source and oracle regression tests. These do NOT certify Oreslang execution.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { expected, verifyGuestStdout } from "./verify-output.mjs";

const read = (relative) => readFileSync(fileURLToPath(new URL(relative, import.meta.url)), "utf8");

test("guest oracle accepts only exact fixture output", () => {
  assert.equal(verifyGuestStdout(expected.join("\n") + "\n"), true);
  assert.throws(() => verifyGuestStdout(expected.join("\n") + "\n\n"), /Expected/);
  assert.throws(() => verifyGuestStdout(expected.slice(1).join("\n") + "\n"), /Expected/);
  assert.throws(() => verifyGuestStdout(expected.join("\n").replace("true", "false")), /mismatch/);
  assert.throws(() => verifyGuestStdout(expected.join("\n") + "\u001b"), /ANSI/);
});

test("source is a pure Oreslang library with fail-closed URL guard", () => {
  const source = read("../client.ores");
  const fixture = read("health_smoke.ores");
  assert.match(source, /define module client as/);
  assert.match(source, /pub fnc valid_base_url\(String base\): bool/);
  assert.match(source, /pub fnc health_url\(String base\): String/);
  assert.match(source, /return base \+ "\/v1\/health"/);
  assert.match(source, /return "";/);
  for (const unsafe of ['"@"', '"?"', '"#"', '"%"', '"\\\\\\\\..."']) {
    if (unsafe === '"\\\\\\\\..."') continue;
    assert.ok(source.includes("contains_literal(" + unsafe + ")"), "missing rejection " + unsafe);
  }
  assert.ok(source.includes('starts_with("https://")'));
  assert.ok(source.includes('contains_literal("\\\\")'));
  assert.ok(source.includes('contains_literal("\\n")'));
  assert.ok(source.includes('contains_literal("\\r")'));
  assert.match(fixture, /import module client from "\.\.\/client"/);
  assert.equal((fixture.match(/stdio\.println\(/g) ?? []).length, expected.length);
  assert.doesNotMatch(source, /\b(?:java\.|fetch\(|http\.|wasm_|JSImport|ffi\.|process\.|stdio\.)/);
});

test("support matrix does not claim unexecuted APM or backend conformance", () => {
  const matrix = read("../../support-matrix.toml");
  assert.match(matrix, /\[languages\.oreslang\][\s\S]*?apm = "pending"/);
  assert.match(matrix, /guest_evidence = "not-attested"/);
  for (const backend of ["java", "llvm", "wasm", "cranelift", "net", "javascript"]) {
    assert.ok(matrix.includes('"' + backend + '"'), "missing requested target " + backend);
  }
});
