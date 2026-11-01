# Oreslang forward proxy (native Oreslang)

**Pre-release configuration/control-plane candidate, not an operational proxy.**

This repository now contains native Oreslang source for strict YAML-subset admission, deterministic route and middleware policy checking, CLI status handling, and self-contained Oreslang contract tests. The network data plane, actor-generation swaps and cross-backend transport integration remain gated. Valid YAML exits 78 instead of pretending an HTTP proxy has started.

Entry: `src/main.ores`. Config: `config/example.yaml`. Runtime architecture and limitations: `docs/ARCHITECTURE.md`. The source tree contains no Python, Rust, JavaScript or shell application scripts.

Config environment variable: **`ores_proxy_conf_yaml`** (lowercase exactly). CLI flag mapping: **`.cli-flags.toml`** for `flags-2-env`.


Further native-Oreslang regression coverage: `tests/middleware_generation_contract.ores` compares independent old/new immutable policy snapshots. See `docs/RELOAD_AND_MIDDLEWARE.md` for proposed actor staging, middleware placement, generation pinning, and drain semantics. **This is a pure test contract, not an implemented hot-reloader.**

Exact-head compiler/contract execution is not yet available; no passing PR CI checks have been observed. Do not advertise active HTTP forwarding until exact-head compiler, contract, and transport tests pass.

A native, **pure control-plane** coordinator in `src/generation.ores` exercises prepare/publish/abort fencing and snapshot epochs (see `tests/generation_contract.ores`). This does not publish a listener/actor generation or serve requests.

## Native verification gate

The legacy [`.github/workflows/native-contracts.yml`](.github/workflows/native-contracts.yml) is retired and intentionally fails closed. Trusted native execution is pending independently reviewed security PR #19 and protected-main runner governance; prerequisites and non-production release gates are in [`docs/NATIVE_VALIDATION.md`](docs/NATIVE_VALIDATION.md). A queued or absent workflow is **not** a passed compiler test. Network serving remains disabled.

## Forward proxy and load-balancer boundary

Forward CONNECT tunneling is an egress-security feature, not a reverse upstream scheduler. Load-balanced egress gateway pools may be added only after CONNECT authentication, destination IP admission/pinning, TLS policy, quotas and actor-owned duplex stream transport are proven. Never rotate a denied destination into a newly eligible route or weaken domain/IP checks to achieve failover. The reverse-proxy repository has a separate experimental YAML backend-pool selection oracle; it does not enable any forward-proxy data plane.

## Native Oreslang CONNECT and HTTP header contracts

`src/proxy_wire.ores` parses only canonical `CONNECT dns-name:443 HTTP/1.1` request metadata and separates syntax admission from a configured-domain predicate. `src/header_policy.ores` implements conservative hop-by-hop/header-injection predicates. `tests/wire_contract.ores` and `tests/header_policy_contract.ores` are Oreslang-only positive/negative test programs. No test run or compiler acceptance is claimed for this PR head.

**CONNECT tunnels are not started.** A domain-name allowlist is not an authorization or SSRF boundary. Before a forward socket is permitted, a runtime transport must provide explicit proxy authentication, request ownership, raw CONNECT framing, safe DNS resolution and IP pinning, byte-stream relay/half-close/backpressure, cancellation, quotas and LLVM parity. Read `docs/WIRE_AND_INGRESS.md` for details.
