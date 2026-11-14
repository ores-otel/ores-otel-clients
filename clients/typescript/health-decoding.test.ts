import {strict as assert} from "node:assert";
import {Client} from "./src/client.ts";
import {ClientError} from "./src/errors.ts";

const client = new Client({baseUrl: "https://otel.example", maxResponseBytes: 4096});
const encode = (value: unknown) => new TextEncoder().encode(JSON.stringify(value));

const success = client.decodeHealth(encode({ok: true, service: "ores-otel", bearer_token: "PRIVATE"}));
assert.deepEqual(success, {ok: true, service: "ores-otel"});
assert.ok(Object.isFrozen(success));
assert.equal("bearer_token" in success, false);

for (const malformed of [
  null, [], true, {}, {ok: "true", service: "ores-otel"},
  {ok: true, service: ""}, {ok: true, service: "https://unsafe/?secret=x"},
  {ok: true, service: "x".repeat(129)},
]) {
  assert.throws(() => client.decodeHealth(encode(malformed)),
    (error: unknown) => error instanceof ClientError && error.code === "invalid_response");
}
assert.throws(() => client.decodeHealth(new Uint8Array([0x7b])),
  (error: unknown) => error instanceof ClientError && error.code === "invalid_json");
