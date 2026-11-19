> **AI agent instructions (organization-wide):** Before working on code, issues, or pull requests, read and follow the [organization `AGENTS.md`](https://github.com/ores-truffle-oreslang/.github/blob/main/AGENTS.md), including its **merge-first stealth-development policy**. Honor any repository-local `AGENTS.md`, explicit holds, and GitHub-enforced rules.

# Oreslang forward proxy (native Oreslang)

## AttoLang migration and current language specification (2026-11-18)

**AttoLang** (formerly **Oreslang**) is the public language identity. This is the legacy `ores-truffle-oreslang/oreslang-forward-proxy-demo.ores` checkout. The new named counterpart is [atto-lang/atto-forward-proxy-demo.atto](https://github.com/atto-lang/atto-forward-proxy-demo.atto). A matching name or related tool does not establish transferred Git history, migrated issues/PRs, or backend parity.

**[atto-spec](https://github.com/atto-lang/atto-spec)** is canonical for normative syntax, ownership, actors and effects; [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance) owns portable positive/negative guest tests and [atto-common-source](https://github.com/atto-lang/atto-common-source) owns portable `.atto` libraries. Current proposals include `snake_case`, `borrow!`/`take!`/`copy!`/`copy!!`/`share!`, [implicit argument borrowing](https://github.com/atto-lang/atto-spec/blob/main/language/implicit-argument-borrow-v1.md), [file/module constants with permitted one-time `os.read_env`](https://github.com/atto-lang/atto-spec/blob/main/language/file-module-const-v1.md), and [`<<<`/`>>>`/`ashr` bitwise shifts distinct from `<<`/`>>` streams](https://github.com/atto-lang/atto-spec/blob/main/language/bitwise-and-stream-operators-v1.md). Design documents are not guest-runtime execution proof.

Keep legacy `.ores`, command, package and ABI names until independently verified migration. No Python scripts, test tools or CI helpers in new AttoLang work; Rust support tools are preferred. Require exact SHA/tree, toolchain and executed positive/negative guest tests for language parity claims; host-only/zero-step CI is **not executed** guest evidence.

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
