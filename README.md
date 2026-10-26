# Oreslang forward proxy (native Oreslang)

**Pre-release configuration/control-plane candidate, not an operational proxy.**

This repository now contains native Oreslang source for strict YAML-subset admission, deterministic route and middleware policy checking, CLI status handling, and self-contained Oreslang contract tests. The network data plane, actor-generation swaps and cross-backend transport integration remain gated. Valid YAML exits 78 instead of pretending an HTTP proxy has started.

Entry: `src/main.ores`. Config: `config/example.yaml`. Runtime architecture and limitations: `docs/ARCHITECTURE.md`. The source tree contains no Python, Rust, JavaScript or shell application scripts.

Config environment variable: **`ores_proxy_conf_yaml`** (lowercase exactly). CLI flag mapping: **`.cli-flags.toml`** for `flags-2-env`.


Further native-Oreslang regression coverage: `tests/middleware_generation_contract.ores` compares independent old/new immutable policy snapshots. See `docs/RELOAD_AND_MIDDLEWARE.md` for proposed actor staging, middleware placement, generation pinning, and drain semantics. **This is a pure test contract, not an implemented hot-reloader.**

Exact-head compiler/contract execution is not yet available; no passing PR CI checks have been observed. Do not advertise active HTTP forwarding until exact-head compiler, contract, and transport tests pass.

A native, **pure control-plane** coordinator in `src/generation.ores` exercises prepare/publish/abort fencing and snapshot epochs (see `tests/generation_contract.ores`). This does not publish a listener/actor generation or serve requests.

## Native verification gate

The exact-head native compiler/contract workflow is [`.github/workflows/native-contracts.yml`](.github/workflows/native-contracts.yml); runner prerequisites, executed commands and non-production release gates are in [`docs/NATIVE_VALIDATION.md`](docs/NATIVE_VALIDATION.md). A queued or absent workflow is **not** a passed compiler test. Network serving remains disabled.

## Native Oreslang CONNECT and HTTP header contracts

`src/proxy_wire.ores` parses only canonical `CONNECT dns-name:443 HTTP/1.1` request metadata and separates syntax admission from a configured-domain predicate. `src/header_policy.ores` implements conservative hop-by-hop/header-injection predicates. `tests/wire_contract.ores` and `tests/header_policy_contract.ores` are Oreslang-only positive/negative test programs. No test run or compiler acceptance is claimed for this PR head.

**CONNECT tunnels are not started.** A domain-name allowlist is not an authorization or SSRF boundary. Before a forward socket is permitted, a runtime transport must provide explicit proxy authentication, request ownership, raw CONNECT framing, safe DNS resolution and IP pinning, byte-stream relay/half-close/backpressure, cancellation, quotas and LLVM parity. Read `docs/WIRE_AND_INGRESS.md` for details.

## Security audit (forward, October 22, 2026)

The runtime is **NOT a forwarding proxy**. No destination capability may be created from `configured_domain`, `configured_connect`, or `upstream_origin` alone. `require_header` means *header presence*, NOT authentication or authorization. Never use it to protect a real upstream service without a separately verified authentication middleware.

The strict YAML subset now uses canonical [a-z0-9-] names for routes/middleware; forbids hop-by-hop, proxy credentials, and request-framing control header names as `require_header`; and rejects arbitrary IPv4 upstream spellings (v0 explicitly permits loopback `127.0.0.1`, `localhost`, or syntactically valid DNS names). Exact DNS/IP/TLS safety remains a separate network-layer release gate. Source policy still lacks a race-free configuration file descriptor and an input byte-size cap before `fs.read_text`.

The Actions workflow now has explicit native Oreslang compile/execute gates for the larger source/test tree, not just YAML. Self-hosted runner admission and actual executed test results are still required; a queued job is not a passing check. The alternative opt-in reverse ingress remains loopback-only and must not be counted as a tested production service.

## Performance evidence

The manual `.github/workflows/perf-connect-policy.yml` workflow measures the current native CONNECT **admission-policy** path with a fixed allow/deny workload and retains five raw timing/RSS samples plus runtime provenance. The workload proves on every admitted iteration that no socket authority is granted.

This is not forward-proxy throughput and is intentionally not plotted against nginx or HAProxy yet. A fair comparison requires all candidates to establish the same HTTP CONNECT tunnel and relay the same bytes; the Oreslang guest transport cannot do that today. [`bench/README.md`](bench/README.md) defines the exact functional and security gates for the future nginx 1.31.8 / HAProxy 3.4.7 tunnel suite.
