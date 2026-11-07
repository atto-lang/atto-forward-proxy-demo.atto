#!/usr/bin/env bash
# Source-policy Git fixture; host only, never compiler or guest execution.
set -euo pipefail
source_root="$(cd "$(dirname -- "$0")/.." && pwd -P)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
git init -q "$fixture"
git -C "$fixture" config user.name 'Forward policy regression'
git -C "$fixture" config user.email 'forward@example.invalid'
git -C "$fixture" config core.filemode true
mkdir -p "$fixture/src"
printf 'define module Worker as\nend\n' > "$fixture/src/worker.ores"
printf 'a%.0s' {1..40} > "$fixture/SOURCE_REF"
printf '\n' >> "$fixture/SOURCE_REF"
git -C "$fixture" add src/worker.ores SOURCE_REF
git -C "$fixture" commit -qm 'source policy baseline'
head="$(git -C "$fixture" rev-parse HEAD)"
check_ok() {
  SOURCE_POLICY_ROOT="$fixture" SOURCE_POLICY_MODE=strict EXPECTED_DEMO_SHA="$head" \
    bash "$source_root/ci/source-policy.sh" >/dev/null
}
check_bad() {
  local expected="$1" output
  if output="$(SOURCE_POLICY_ROOT="$fixture" SOURCE_POLICY_MODE=strict EXPECTED_DEMO_SHA="$head" \
    bash "$source_root/ci/source-policy.sh" 2>&1)"; then
    echo "unexpected source-policy admission: $expected" >&2
    exit 1
  fi
  [[ "$output" == *"$expected"* ]] || {
    printf 'missing expected denial (%s): %s\n' "$expected" "$output" >&2
    exit 1
  }
}
check_ok
# The pin's Git index object mode is part of its authority, not just bytes.
chmod +x "$fixture/SOURCE_REF"
git -C "$fixture" add SOURCE_REF
check_bad 'SOURCE_REF must be a tracked regular blob'
git -C "$fixture" reset --hard -q HEAD
check_ok
# Gitlink entries (160000) cannot impersonate ordinary 100644 pin blobs.
git -C "$fixture" update-index --add --cacheinfo "160000,$head,SOURCE_REF"
check_bad 'SOURCE_REF must be a tracked regular blob'
git -C "$fixture" reset --hard -q HEAD
check_ok
# A tracked symlink cannot carry the compiler revision.
rm "$fixture/SOURCE_REF"
ln -s src/worker.ores "$fixture/SOURCE_REF"
git -C "$fixture" add SOURCE_REF
check_bad 'SOURCE_REF must be a regular, non-symlinked file'
git -C "$fixture" reset --hard -q HEAD
check_ok
# An untracked pin is not sufficient merely because it has expected bytes.
git -C "$fixture" rm -q --cached SOURCE_REF
check_bad 'SOURCE_REF must be tracked'
git -C "$fixture" reset --hard -q HEAD
check_ok
echo 'FORWARD_PIN_MODE_GITLINK_HOST_PASS; GUEST_NOT_EXECUTED'
