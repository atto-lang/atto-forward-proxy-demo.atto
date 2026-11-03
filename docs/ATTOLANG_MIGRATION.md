# AttoLang source-extension migration

This branch migrates the active forward-proxy semantic stack from the former Oreslang public name and `.ores` guest-source extension to **AttoLang** and `.atto`.

The migration parent is exact commit `2f08b29bc7a7d50db95696f7baa25f118d4a0abc` (forward PR #10). Historical frozen release PR #12 remains untouched at its existing `.ores` SHA/tree.

## Compatibility boundary

New guest source and tests use `.atto`; user-facing source comments and validation docs use **AttoLang**. Existing runtime/CLI compatibility identifiers such as the `oreslang` executable, `ORESLANG_*` Actions variables, repository names and runner label `oreslang-jdk25` remain until a separately reviewed runtime-provenance migration attests replacements.

The forward CONNECT policy remains data-only planning and must preserve `socket_authorized=false` and `may_connect=false`.

## Gate

`ci/attolang_source_policy.sh` rejects tracked or untracked legacy `.ores` files, symlinked/misplaced `.atto` files, executable-bit drift, writable-mode drift and working-tree byte drift. The source-free harness exercises thirteen cases.

This is source/contract migration evidence only, not native AttoLang execution.
