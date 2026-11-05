#!/usr/bin/env bash
# Source-local host regression only; no compiler, network or guest execution.
set -euo pipefail
source_root="$(cd "$(dirname "$0")/.." && pwd -P)"
test_repo="$(mktemp -d)"
trap 'rm -rf -- "$test_repo"' EXIT
git init -q "$test_repo"
git -C "$test_repo" config user.name 'Source policy fixture'
git -C "$test_repo" config user.email 'fixture@example.invalid'
mkdir -p "$test_repo/src" "$test_repo/scripts"
printf 'actor fixture\n' > "$test_repo/src/worker.ores"
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add .
git -C "$test_repo" commit -qm 'baseline'
head="$(git -C "$test_repo" rev-parse HEAD)"
admit() {
  SOURCE_POLICY_ROOT="$test_repo" SOURCE_POLICY_MODE=strict EXPECTED_DEMO_SHA="$head" \
    bash "$source_root/ci/source-policy.sh" >/dev/null
}
deny() {
  if SOURCE_POLICY_ROOT="$test_repo" SOURCE_POLICY_MODE=strict EXPECTED_DEMO_SHA="$head" \
     bash "$source_root/ci/source-policy.sh" >/dev/null 2>&1; then
    echo 'POLICY_NEGATIVE_UNEXPECTED_ADMISSION' >&2
    exit 1
  fi
}
admit
# Git-tracked provenance must be exactly a single lowercase SHA and LF.
printf 'A%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add SOURCE_REF
deny
printf 'a%.0s' {1..39} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add SOURCE_REF
deny
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
git -C "$test_repo" add SOURCE_REF
deny
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\r\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add SOURCE_REF
deny
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\nextra\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add SOURCE_REF
deny
git -C "$test_repo" checkout HEAD -- SOURCE_REF
admit
# Escaped extensions and case aliases cannot become tracked Python source.
printf 'test\n' > "$test_repo/src/unauthorized.PYI"
git -C "$test_repo" add src/unauthorized.PYI
deny
git -C "$test_repo" rm -q -f src/unauthorized.PYI
printf 'test\n' > "$test_repo/scripts/benchmark.py"
git -C "$test_repo" add scripts/benchmark.py
deny
SOURCE_POLICY_ROOT="$test_repo" SOURCE_POLICY_MODE=rest-legacy EXPECTED_DEMO_SHA="$head" \
  bash "$source_root/ci/source-policy.sh" >/dev/null
git -C "$test_repo" rm -q -f scripts/benchmark.py
admit
# A wrong lease and unknown mode must never authorize source inventory.
if SOURCE_POLICY_ROOT="$test_repo" EXPECTED_DEMO_SHA="$(printf '0%.0s' {1..40})" \
  bash "$source_root/ci/source-policy.sh" >/dev/null 2>&1; then exit 1; fi
if SOURCE_POLICY_ROOT="$test_repo" SOURCE_POLICY_MODE='REST-LEGACY' \
  bash "$source_root/ci/source-policy.sh" >/dev/null 2>&1; then exit 1; fi
echo 'FORWARD_SOURCE_POLICY_MEMBER_BUDGET_HOST_PASS guest=NOT_EXECUTED'
