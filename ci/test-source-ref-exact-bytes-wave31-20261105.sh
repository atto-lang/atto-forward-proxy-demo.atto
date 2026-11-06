#!/usr/bin/env bash
# Host-only source gate regression: never claims guest/compiler execution.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.name "Source gate fixture"
git -C "$tmp" config user.email "fixture@example.invalid"
mkdir -p "$tmp/src"
printf 'pub routine main(): void { return; }\n' > "$tmp/src/main.ores"
restore_ref() {
  rm -f "$tmp/SOURCE_REF"
  printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"
  printf '\n' >> "$tmp/SOURCE_REF"
  chmod 644 "$tmp/SOURCE_REF"
  git -C "$tmp" add SOURCE_REF
}
restore_ref
git -C "$tmp" add .
git -C "$tmp" commit -qm "host source fixture"
sha="$(git -C "$tmp" rev-parse HEAD)"

run_ok() {
  SOURCE_POLICY_ROOT="$tmp" EXPECTED_DEMO_SHA="$sha" \
    bash "$root/ci/source-policy.sh" > "$tmp/out" 2>&1
  grep -Fq SOURCE_POLICY_STRUCTURAL_PASS "$tmp/out"
  grep -Fq NOT_EXECUTED "$tmp/out"
}
run_bad() {
  if SOURCE_POLICY_ROOT="$tmp" EXPECTED_DEMO_SHA="$sha" \
      bash "$root/ci/source-policy.sh" > "$tmp/out" 2>&1; then
    printf 'HOST_GATE_MUTATION_MISSED: %s\n' "$1" >&2
    exit 1
  fi
  grep -Fq POLICY_FAILURE "$tmp/out"
}
run_ok
# A CRLF line must not pass the exact 40 lowercase hex + LF contract.
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"
printf '\r\n' >> "$tmp/SOURCE_REF"
git -C "$tmp" add SOURCE_REF
run_bad carriage_return
restore_ref
run_ok

# A lowercase-only pin cannot be laundered by valid-looking uppercase bytes.
printf 'A%.0s' {1..40} > "$tmp/SOURCE_REF"
printf '\n' >> "$tmp/SOURCE_REF"
git -C "$tmp" add SOURCE_REF
run_bad uppercase_digest
restore_ref
run_ok

# A valid-looking but untracked pin cannot serve as source authority.
git -C "$tmp" rm -q --cached -- SOURCE_REF
run_bad untracked_ref
git -C "$tmp" add SOURCE_REF
run_ok

# Any source file extension is checked case-insensitively.
printf 'print(1)\n' > "$tmp/src/foreign.PyI"
git -C "$tmp" add src/foreign.PyI
run_bad mixed_case_python
git -C "$tmp" rm -q -f -- src/foreign.PyI
run_ok

# Caller-provided HEAD cannot silently change source identity.
if SOURCE_POLICY_ROOT="$tmp" EXPECTED_DEMO_SHA="$(printf '0%.0s' {1..40})" \
  bash "$root/ci/source-policy.sh" > "$tmp/out" 2>&1; then
  echo 'HOST_GATE_MUTATION_MISSED: forged head' >&2
  exit 1
fi
grep -Fq POLICY_FAILURE "$tmp/out"
run_ok
printf 'HOST_ONLY_FORWARD_REF_ADMISSION_PASS negatives=5; NOT_COMPILER_EXECUTION\n'
