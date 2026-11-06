import assert from "node:assert/strict";
import http from "node:http";
import test from "node:test";
import { Client } from "./src/client.ts";
import { ClientError } from "./src/errors.ts";

// The real TypeScript SDK consumes responses from a real loopback HTTP server.
// This fixture does not certify an OTel production server.
async function withHealth(handler: http.RequestListener, run: (base: string) => Promise<void>) {
  const server = http.createServer(handler);
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  try {
    const address = server.address();
    if (!address || typeof address === "string") throw new Error("missing port");
    await run("http://127.0.0.1:" + address.port);
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => error ? reject(error) : resolve()));
  }
}

test("real SDK decodes concurrent HTTP health responses across the wire", async () => {
  let requests = 0;
  await withHealth((req, res) => {
    requests += 1;
    if (req.method !== "GET" || req.url !== "/v1/health") {
      res.writeHead(404).end();
      return;
    }
    res.writeHead(200, {"content-type": "application/json"});
    res.end(JSON.stringify({ ok: true, service: "ores-otel-api-server" }));
  }, async (base) => {
    const client = new Client({baseUrl: base + "/", maxResponseBytes: 1024});
    const results = await Promise.all(Array.from({length: 12}, async () => {
      const response = await fetch(client.healthUrl(), {signal: AbortSignal.timeout(3000)});
      assert.equal(response.status, 200);
      return client.decodeHealth(new Uint8Array(await response.arrayBuffer()));
    }));
    assert.equal(requests, 12);
    assert.ok(results.every((result) => result.ok && result.service === "ores-otel-api-server"));
  });
});

test("SDK rejects malformed JSON from a real HTTP upstream", async () => {
  await withHealth((_req, res) => {
    res.writeHead(200, {"content-type": "application/json"}).end("{");
  }, async (base) => {
    const client = new Client({baseUrl: base, maxResponseBytes: 1024});
    const response = await fetch(client.healthUrl());
    const body = new Uint8Array(await response.arrayBuffer());
    assert.throws(() => client.decodeHealth(body),
      (error: unknown) => error instanceof ClientError && error.code === "invalid_json");
  });
});

test("SDK refuses oversized real HTTP response even with valid JSON", async () => {
  await withHealth((_req, res) => {
    res.writeHead(200, {"content-type": "application/json"});
    res.end(JSON.stringify({ok: true, service: "a".repeat(4096)}));
  }, async (base) => {
    const client = new Client({baseUrl: base, maxResponseBytes: 1024});
    const response = await fetch(client.healthUrl());
    const bytes = new Uint8Array(await response.arrayBuffer());
    assert.throws(() => client.decodeHealth(bytes),
      (error: unknown) => error instanceof ClientError && error.code === "too_large");
  });
});
