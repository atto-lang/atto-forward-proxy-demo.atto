#!/usr/bin/env bash
# Reject a forged or stale expected-HEAD lease in source-free policy.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.name 'Policy fixture'
git -C "$tmp" config user.email 'fixture@example.invalid'
mkdir -p "$tmp/src"
printf 'actor fixture\n' > "$tmp/src/worker.ores"
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"
printf '\n' >> "$tmp/SOURCE_REF"
git -C "$tmp" add .
git -C "$tmp" commit -qm baseline
head="$(git -C "$tmp" rev-parse HEAD)"
pass() { SOURCE_POLICY_ROOT="$tmp" EXPECTED_DEMO_SHA="$1" bash "$root/ci/source-policy.sh" >/dev/null; }
deny() { if SOURCE_POLICY_ROOT="$tmp" EXPECTED_DEMO_SHA="$1" bash "$root/ci/source-policy.sh" >/dev/null 2>&1; then echo 'POLICY_HEAD_LEASE_BYPASS' >&2; exit 1; fi; }
pass "$head"
deny 'not-a-commit'
deny "$(printf '0%.0s' {1..40})"
deny "${head^^}"
# A valid SHA is not a lease for a changed commit.
printf 'next\n' >> "$tmp/src/worker.ores"
git -C "$tmp" add src/worker.ores
git -C "$tmp" commit -qm next
deny "$head"
pass "$(git -C "$tmp" rev-parse HEAD)"
echo 'SOURCE_POLICY_EXPECTED_HEAD_HOST_PASS cases=6 guest=NOT_EXECUTED'
