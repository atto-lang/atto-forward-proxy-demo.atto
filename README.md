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

## Repository ownership and migration (2026-11-08)

This source repository remains `ores-truffle-oreslang/oreslang-forward-proxy-demo.ores` until an authorized transfer. The public language name is **AttoLang**; existing `.ores` source and `oreslang-*` packages, repos and CLI names are compatibility contracts, not automatically renamed.

- **Belongs here:** forward proxy guest policy, bounded transport experiments and safe negative cases.
- **Must live elsewhere:** production unreviewed Internet egress gateway or TLS bypass.
- **Organization boundary:** [atto-lang](https://github.com/atto-lang) owns language/compiler/runtime specifications, portable libraries, CLI and testable demos; [atto-co](https://github.com/atto-co) separately manages hosted cloud infrastructure, deployed customer services, tenancy, identity, billing and production operations. An existing `atto-*` repository is not evidence of this repo's transferred identity or tested implementation parity.
- **First-step migration proposal:** `atto-lang/oreslang-forward-proxy-demo.ores` via a real GitHub ownership transfer preserving old name, full history and numeric repository ID. **No direct legacy-org → atto-co transfer is authorized** in this wave; any later managed-product carve-out requires independent review.

**Preflight:** coordinate in [issue #26](https://github.com/ores-truffle-oreslang/.github/issues/26); consult the private [migration PR #25](https://github.com/ores-truffle-oreslang/.github/pull/25). Record exact source HEAD SHA/tree and stable ID, source/target owner and independent security signoff, target permissions/protected rulesets, PRs, tags/releases, packages, Apps, secrets, webhooks, Pages, Actions/runner admission, external consumers and rollback owner. No private source mirrors as shortcuts. Only after the authorized transfer validate unchanged ID/history/tree, rebind security checks, then update references and run executable exact-head CI. `steps=[]`/`null` means `NOT_EXECUTED`; structural host-only evidence does not certify guest execution or production networking/database behavior.
