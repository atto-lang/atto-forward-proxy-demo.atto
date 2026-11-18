# atto-forward-proxy-demo.atto

Forward proxy example demonstrating AttoLang networking and request forwarding.

## Naming migration and language authority

This repository is maintained at [atto-lang/atto-forward-proxy-demo.atto](https://github.com/atto-lang/atto-forward-proxy-demo.atto); use `https://github.com/atto-lang/atto-forward-proxy-demo.atto.git` for Git remotes and canonical `.atto` source examples. The normative language contract is [atto-spec](https://github.com/atto-lang/atto-spec), with executable guest evidence tracked by [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance). Follow current ownership, borrowing, effects, actor, and syntax rules there; do not infer implemented features from a README or unexecuted CI.

## Demonstration focus

Outbound proxying, host permissions, and resource cleanup.

## Running the example

Inspect the checked-in source, project manifest, and workflows for supported compiler backends and actual run commands. Source files use the intended `.atto` extension for AttoLang; backend support must be confirmed rather than presumed.

## Expected verification

Examples should document their dependencies, expected output, negative/error cases, and exact compiler/runtime versions used to verify execution. Host-side tests do not establish AttoLang guest execution.

## Status

This README describes the demonstration's intended purpose. Current executable coverage and feature support should be verified against code and CI.

## AttoLang ecosystem

- [AttoLang](https://github.com/atto-lang)
- [Specification](https://github.com/atto-lang/atto-spec)
- [Platform conformance](https://github.com/atto-lang/atto-platform-conformance)

## Repository ownership and contribution routing

**Belongs here:** A documented forward HTTP(S) proxy example, outbound policy checks, request relay, connection lifecycle and demo fixtures.

**Belongs elsewhere:** Reverse proxy routing demo belongs in atto-reverse-proxy-demo.atto; generic HTTP routing in atto-http-routing; commercial edge services in atto-co.

**Security and portability boundary:** Disable open-proxy defaults, forbid SSRF/internal metadata targets, bind outbound allowlists, auth, DNS re-resolution protections and bounded tunnel/stream quotas.

AttoLang is the canonical project name; new source, examples and documentation use `.atto` and the `atto-lang` repository organization. This README defines scope, not feature readiness.

**Acceptance:** name exact source SHA/tree, runtime/toolchain, positive and negative checks and execution receipt before claiming support. Host-only tests and empty CI steps do not prove guest execution.
