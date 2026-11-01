# Oreslang SDK — first portable health slice

This is an Oreslang **source implementation** of the pure request preparation part
of the ORES client contract: validate an origin-only HTTPS base and construct
the absolute health URL. Import `client.ores` in Oreslang source. There is **no network
client, APM decoder, bearer authentication, OTLP exporter or SDK release** here
yet. An empty result means invalid input and MUST NOT be sent to a transport.

The source is deliberately independent of Java, .NET, JavaScript, WASI, an
HTTP runtime, and mutable globals. No claim is made that any particular
compiler currently compiles it. This is the common source required to begin
compiler-backed conformance.

For telemetry spans, structured logs and integer metrics, use the existing
[Oreslang-native telemetry library](https://github.com/ores-truffle-oreslang/oreslang-otel).
Its JSON Lines records are **not OTLP** and its first verified compiler target
is Java/GraalVM; this client does not silently substitute that format for the
ORES APM or logger wire contracts.

## Source and runtime

```ores
import module client from "./clients/oreslang/client";
val String url = client.health_url("https://telemetry.example:443");
if url != ""; then
  // Inject a runtime-owned TLS transport with an explicit bearer token,
  // deadline, and a bounded response decoder; no transport is bundled.
fi
```

Host-only source/oracle checks:

```sh
node --test clients/oreslang/tests/source-contract.test.mjs
```

For EACH backend, compile and execute `tests/health_smoke.ores` using its actual
toolchain, capturing its stdout verbatim (do not synthesize model output):

```sh
node clients/oreslang/tests/verify-output.mjs /path/to/guest-stdout.txt
```

A valid source-only test run **must not be promoted** to a compiled guest pass.
Backend evidence must include the exact compiler source/commit, guest source
commit, compiler target, executable/run command, exit status, and captured
stdout; JavaScript transpilation and WASM execution require their own target-
specific execution and must not be inferred from native compilation.

| Backend | Admission gate |
| --- | --- |
| Java/GraalVM | Real compiler guest JIT, AOT and hybrid where supported |
| LLVM | Native compiler-generated guest, plus ASan/UBSan runtime checks |
| WASM | Guest module executed in browser or Node worker with explicit host imports |
| Cranelift | Compiler-generated guest, not a Rust/host model substitute |
| .NET | Native AOT generated guest on supported target OS |
| JavaScript | Run the Oreslang-to-JS transpiled guest under Node, Deno or a browser |

After executable source parity, implement the injected HTTPS/bearer/deadline/
bounded-response API and validate the pinned TypeSpec + JSON Schema peer
authorities before promoting APM or health network capability. No new
telemetry wire schema is invented by this slice.
