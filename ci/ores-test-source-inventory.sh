#!/usr/bin/env bash
# Hermetic host-shell adversarial regressions; does not access private source.
set -euo pipefail
script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/ores-verify-source-inventory.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.name 'Inventory check'
git config user.email 'check@example.invalid'
mkdir -p src tests ci
printf 'candidate\n' > src/a.ores
printf 'contract\n' > tests/b.ores
printf 'src/a.ores\ntests/b.ores\n' > ci/oreslang-files.txt
printf 'tests/b.ores\n' > ci/pure-contracts.txt
git add .
git commit -qm fixture
pass() { SOURCE_MANIFEST_ROOT="$tmp" bash "$script" >/dev/null; }
reject() { if SOURCE_MANIFEST_ROOT="$tmp" bash "$script" >/dev/null 2>&1; then
  echo 'TEST_FAILURE: invalid inventory accepted' >&2; exit 1; fi; }
pass
printf 'new\n' > src/extra.ores
git add src/extra.ores
reject
git rm -q -f src/extra.ores
pass
printf 'src/a.ores\nsrc/a.ores\ntests/b.ores\n' > ci/oreslang-files.txt
reject
printf 'src/a.ores\ntests/b.ores\n' > ci/oreslang-files.txt
pass
printf 'src/a.ores\n' > ci/pure-contracts.txt
reject
printf 'tests/b.ores\n' > ci/pure-contracts.txt
pass
git rm -q -f src/a.ores
reject
mkdir -p src
printf 'candidate\n' > src/a.ores
git add src/a.ores
pass
git rm -q -f src/a.ores
mkdir -p src
ln -s b.ores src/a.ores
git add src/a.ores
reject
git rm -q -f src/a.ores
mkdir -p src
printf 'candidate\n' > src/a.ores
git add src/a.ores
pass
mkdir -p src/sub
printf 'nested\n' > src/sub/new.ores
git add src/sub/new.ores
reject
git rm -q -f src/sub/new.ores
pass
printf 'other\n' > tests/extra.ores
git add tests/extra.ores
reject
git rm -q -f tests/extra.ores
pass
# An inherited alternate index must not hide an extra tracked Oreslang source.
GIT_INDEX_FILE="$tmp/.git/alternate-index" git read-tree HEAD
printf 'hidden\\n' > src/hidden.ores
git add src/hidden.ores
GIT_INDEX_FILE="$tmp/.git/alternate-index" reject
git rm -q -f src/hidden.ores
pass
# A damaged real index must fail rather than be masked by process substitution.
cp "$tmp/.git/index" "$tmp/index-backup"
printf 'corrupt-index\\n' > "$tmp/.git/index"
reject
mv "$tmp/index-backup" "$tmp/.git/index"
pass
printf 'SOURCE_INVENTORY_NEGATIVE_TESTS_PASS scenarios=9\\n'
