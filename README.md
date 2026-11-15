# atto-forward-proxy-demo.atto

Forward proxy example demonstrating AttoLang networking and request forwarding.

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

AttoLang is the public name; preserve existing Oreslang/.ores compatibility and use canonical .atto for new portable library source. This README defines scope, not feature readiness.

**Acceptance:** name exact source SHA/tree, runtime/toolchain, positive and negative checks and execution receipt before claiming support. Host-only tests and empty CI steps do not prove guest execution.
