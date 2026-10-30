# Demo validation gates

Status snapshot: 2026-10-29. This checklist is not execution evidence.

## Scope
Forward proxy control plane.

## Required tests
Execute exact-head native contract tests; verify reject paths for CONNECT, DNS rebinding, denied egress and relay shutdown before enabling transport.

Record exact demo and compiler Git SHAs, compiler executable SHA-256, backend, exit codes, expected vs actual outputs, runner identity and actual CI steps. A missing compiler, pending job or zero-step GitHub Action is **NOT_EXECUTED**, not a source failure or test pass.

## Limits
No CONNECT tunnel or real proxy data plane.

Use real Oreslang guests for guest claims; keep host adapters distinct. Add malformed-input, bounded-resource, stale-generation and shutdown negatives where applicable. Do not assume backend parity or production readiness. Private code may only be mirrored to separately approved private carriers with exact tree and per-blob verification and no secrets.
