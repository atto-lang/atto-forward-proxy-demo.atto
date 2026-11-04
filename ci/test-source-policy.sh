#!/usr/bin/env bash
# Adversarial hermetic tests of the exact policy gate used in CI.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_repo="$(mktemp -d)"
trap 'rm -rf "$test_repo"' EXIT
git init -q "$test_repo"
git -C "$test_repo" config user.name "Policy test"
git -C "$test_repo" config user.email "policy@example.invalid"
mkdir -p "$test_repo/docs" "$test_repo/src"
printf '00_abc\n' > "$test_repo/src/hello.ores"
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add .
check_ok() {
  SOURCE_POLICY_ROOT="$test_repo" SOURCE_POLICY_MODE="${1:-strict}" bash "$root/ci/source-policy.sh" > /dev/null
}
check_bad() {
  if SOURCE_POLICY_ROOT="$test_repo" SOURCE_POLICY_MODE="${1:-strict}" bash "$root/ci/source-policy.sh" > /dev/null 2>&1; then
    echo "TEST_FAILURE: expected source policy rejection" >&2; exit 1
  fi
}
check_ok
mkdir -p "$test_repo/nested space"
printf 'placeholder\n' > "$test_repo/nested space/unsafe.PY"
git -C "$test_repo" add .
check_bad
git -C "$test_repo" rm -q -f -- "nested space/unsafe.PY"
printf 'placeholder\n' > "$test_repo/src/escape.ipynb"
git -C "$test_repo" add .
check_bad
git -C "$test_repo" rm -q -f -- src/escape.ipynb
printf '#!/usr/bin/env python3\n' > "$test_repo/runner"
git -C "$test_repo" add .
check_bad
git -C "$test_repo" rm -q -f -- runner
# GNU env -S strips quotes and concatenates quoted interpreter fragments.
# All of these execute Python on Linux, despite the original shebang regex.
for interpreter in "'python3'" '"python3"' "'py''thon3'"; do
  printf '#!/usr/bin/env -S %s\n' "$interpreter" > "$test_repo/quoted-interpreter"
  git -C "$test_repo" add quoted-interpreter
  check_bad
  git -C "$test_repo" rm -q -f -- quoted-interpreter
done
# GNU env -S also expands environment variables before interpreter lookup.
# Reject both unquoted and quoted variable-based executable selection.
for interpreter in '${ORES_POLICY_INTERPRETER}' '"${ORES_POLICY_INTERPRETER}"'; do
  printf '#!/usr/bin/env -S %s\n' "$interpreter" > "$test_repo/dynamic-interpreter"
  git -C "$test_repo" add dynamic-interpreter
  check_bad
  git -C "$test_repo" rm -q -f -- dynamic-interpreter
done
# Reject ABI/debug interpreters not caught by a digits-and-dots-only regex.
for interpreter in python3.7m python3.11-dbg python3.11d; do
  printf '#!/usr/bin/env -S %s\n' "$interpreter" > "$test_repo/abi-interpreter"
  git -C "$test_repo" add abi-interpreter
  check_bad
  git -C "$test_repo" rm -q -f -- abi-interpreter
done
printf '#!/usr/bin/python3.7m\n' > "$test_repo/direct-abi-interpreter"
git -C "$test_repo" add direct-abi-interpreter
check_bad
git -C "$test_repo" rm -q -f -- direct-abi-interpreter
# GNU env -S interprets \_ as a word separator before selecting Python.
# The original backslash-removal regex sees _python3 and incorrectly permits it.
for interpreter in '\_python3' '\_ python3'; do
  printf '#!/usr/bin/env -S %s\n' "$interpreter" > "$test_repo/escaped-separator"
  git -C "$test_repo" add escaped-separator
  check_bad
  git -C "$test_repo" rm -q -f -- escaped-separator
done
# The stricter guard must not reject unrelated interpreters.
printf '#!/usr/bin/env node\n' > "$test_repo/node-interpreter"
git -C "$test_repo" add node-interpreter
check_ok
git -C "$test_repo" rm -q -f -- node-interpreter
ln -s hello.ores "$test_repo/src/alias.ores"
git -C "$test_repo" add .
check_bad
git -C "$test_repo" rm -q -f -- src/alias.ores
printf 'bad\n' > "$test_repo/SOURCE_REF"
git -C "$test_repo" add .
check_bad
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add .
check_ok
# SOURCE_REF is a non-executable provenance file. A 100755 stage entry must
# fail even with canonical SHA bytes and a clean regular worktree.
git -C "$test_repo" update-index --chmod=+x -- SOURCE_REF
check_bad
git -C "$test_repo" update-index --chmod=-x -- SOURCE_REF
check_ok
mkdir -p "$test_repo/scripts"
printf 'legacy\n' > "$test_repo/scripts/benchmark.py"
git -C "$test_repo" add .
check_bad
check_ok rest-legacy
printf 'new\n' > "$test_repo/scripts/new_tool.py"
git -C "$test_repo" add .
check_bad rest-legacy
git -C "$test_repo" rm -q -f -- scripts/new_tool.py scripts/benchmark.py
ln -s /etc/hosts "$test_repo/README.md"
git -C "$test_repo" add .
check_bad
git -C "$test_repo" rm -q -f -- README.md
rm -f "$test_repo/SOURCE_REF"
ln -s /etc/hosts "$test_repo/SOURCE_REF"
git -C "$test_repo" add .
check_bad
git -C "$test_repo" rm -q -f -- SOURCE_REF
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add .
check_ok
git -C "$test_repo" update-index --add --cacheinfo 160000,0123456789012345678901234567890123456789,src/dependency
check_bad
git -C "$test_repo" update-index --force-remove src/dependency
rm -f "$test_repo/src/hello.ores"
check_bad
printf '00_abc\n' > "$test_repo/src/hello.ores"
check_ok
git -C "$test_repo" rm -q -f SOURCE_REF
printf 'b%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
check_bad
# A tracked SOURCE_REF deleted only from the worktree must fail.
rm -f "$test_repo/SOURCE_REF"
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add SOURCE_REF
rm "$test_repo/SOURCE_REF"
check_bad
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
git -C "$test_repo" add SOURCE_REF
check_ok
# A missing optional SOURCE_REF plus poisoned index must not hide Python.
git -C "$test_repo" rm -q -f -- SOURCE_REF
printf 'print(1)\n' > "$test_repo/src/hidden.py"
git -C "$test_repo" add src/hidden.py
GIT_INDEX_FILE="$test_repo/.git/nonexistent-index" check_bad
git -C "$test_repo" rm -q -f -- src/hidden.py
check_ok
# An unreadable/corrupt real index must fail before either audit loop.
cp "$test_repo/.git/index" "$test_repo/index-backup"
printf 'corrupt-index\n' > "$test_repo/.git/index"
check_bad
mv "$test_repo/index-backup" "$test_repo/.git/index"
check_ok
# A forged staged Python blob hidden behind benign worktree bytes must fail.
printf 'safe\n' > "$test_repo/src/disguised.txt"
git -C "$test_repo" add src/disguised.txt
check_ok
forged_blob="$(printf '#!/usr/bin/env python3\nprint(1)\n' | git -C "$test_repo" hash-object -w --stdin)"
git -C "$test_repo" update-index --cacheinfo "100644,$forged_blob,src/disguised.txt"
check_bad
git -C "$test_repo" add src/disguised.txt
check_ok
git -C "$test_repo" rm -q -f -- src/disguised.txt
check_ok
# A symlinked *parent* can lead to an external regular file with the same
# Git blob: -f, ! -L on the leaf, and hash-object all accepted this before.
external_dir="$test_repo.external"
mkdir -p "$external_dir"
cp "$test_repo/src/hello.ores" "$external_dir/hello.ores"
mv "$test_repo/src" "$test_repo/src-original"
ln -s "$external_dir" "$test_repo/src"
check_bad
rm "$test_repo/src"
mv "$test_repo/src-original" "$test_repo/src"
rm -rf "$external_dir"
check_ok
# An untracked but SHA-shaped SOURCE_REF is not provenance.
printf 'a%.0s' {1..40} > "$test_repo/SOURCE_REF"
printf '\n' >> "$test_repo/SOURCE_REF"
check_bad
# A SHA-pinned production audit must not be redirected to a clean sibling
# checkout. Both clones have identical HEAD but the invoking tree is dirty.
redirect_case="$test_repo/sha-override"
git init -q "$redirect_case/clean"
git -C "$redirect_case/clean" config user.name "Policy test"
git -C "$redirect_case/clean" config user.email "policy@example.invalid"
mkdir -p "$redirect_case/clean/src"
printf 'safe\n' > "$redirect_case/clean/src/hello.ores"
git -C "$redirect_case/clean" add .
git -C "$redirect_case/clean" commit -q -m 'clean baseline'
git clone -q "$redirect_case/clean" "$redirect_case/dirty"
mkdir -p "$redirect_case/dirty/ci"
cp "$root/ci/source-policy.sh" "$redirect_case/dirty/ci/source-policy.sh"
printf '#!/usr/bin/env python3\n' > "$redirect_case/dirty/src/hello.ores"
redirect_sha="$(git -C "$redirect_case/dirty" rev-parse HEAD)"
if SOURCE_POLICY_ROOT="$redirect_case/clean" EXPECTED_DEMO_SHA="$redirect_sha" \
  bash "$redirect_case/dirty/ci/source-policy.sh" > "$redirect_case/result.log" 2>&1; then
  echo "TEST_FAILURE: SHA-pinned policy accepted redirected clean checkout" >&2
  exit 1
fi
grep -Fq 'POLICY_FAILURE: SHA-pinned audit cannot redirect SOURCE_POLICY_ROOT' "$redirect_case/result.log" || {
  echo "TEST_FAILURE: redirected SHA-pinned audit did not fail at root binding" >&2
  exit 1
}
# A SHA-pinned production audit must prove its full HEAD tree, not merely
# that a stale HEAD points at the expected commit. Verify staged removals,
# staged additions, ignored extra inputs and executable-bit drift.
pinned_repo="$test_repo/pinned-audit"
mkdir -p "$pinned_repo/ci" "$pinned_repo/docs"
cp "$root/ci/source-policy.sh" "$pinned_repo/ci/source-policy.sh"
printf 'safe tracked bytes\n' > "$pinned_repo/docs/allowed.txt"
git init -q "$pinned_repo"
git -C "$pinned_repo" config user.name 'Policy pinned test'
git -C "$pinned_repo" config user.email 'policy@example.invalid'
git -C "$pinned_repo" add .
git -C "$pinned_repo" commit -q -m 'exact pinned source'
pinned_sha="$(git -C "$pinned_repo" rev-parse HEAD)"
pinned_ok() {
  EXPECTED_DEMO_SHA="$pinned_sha" bash "$pinned_repo/ci/source-policy.sh" > /dev/null || {
    echo 'TEST_FAILURE: clean SHA-pinned checkout was rejected' >&2; exit 1;
  }
}
pinned_bad() {
  if EXPECTED_DEMO_SHA="$pinned_sha" bash "$pinned_repo/ci/source-policy.sh" >/dev/null 2>&1; then
    echo 'TEST_FAILURE: modified SHA-pinned checkout was accepted' >&2; exit 1
  fi
}
pinned_ok
# Regression: migration-only Python allowlisting must not be accepted by an
# otherwise clean, exact-head production audit.
if EXPECTED_DEMO_SHA="$pinned_sha" SOURCE_POLICY_MODE=rest-legacy \
  bash "$pinned_repo/ci/source-policy.sh" > /dev/null 2>&1; then
  echo 'TEST_FAILURE: SHA-pinned audit accepted rest-legacy source policy' >&2
  exit 1
fi
git -C "$pinned_repo" rm -q -- docs/allowed.txt
pinned_bad
git -C "$pinned_repo" reset --hard -q HEAD
printf 'unreviewed safe file\n' > "$pinned_repo/docs/addition.txt"
git -C "$pinned_repo" add docs/addition.txt
pinned_bad
git -C "$pinned_repo" reset --hard -q HEAD
printf 'ignored\n' > "$pinned_repo/docs/ignored.txt"
printf 'docs/ignored.txt\n' > "$pinned_repo/.git/info/exclude"
pinned_bad
rm "$pinned_repo/docs/ignored.txt"
# core.filemode=false must not allow executable-bit changes to escape a
# SHA-pinned checkout audit on a Linux CI worker.
git -C "$pinned_repo" config core.filemode false
chmod +x "$pinned_repo/docs/allowed.txt"
pinned_bad
chmod -x "$pinned_repo/docs/allowed.txt"
git -C "$pinned_repo" config --unset core.filemode
pinned_ok

# The tracked-file verifier must reject huge inputs BEFORE hashing them.
# A separate fixture prevents the earlier deliberately dirty index and
# SOURCE_REF-negative cases from masking budget regressions.
budget_repo="$test_repo/byte-budget"
mkdir -p "$budget_repo/docs"
git init -q "$budget_repo"
git -C "$budget_repo" config user.name 'Budget policy fixture'
git -C "$budget_repo" config user.email 'policy@example.invalid'
printf 'safe\n' > "$budget_repo/docs/small.txt"
git -C "$budget_repo" add docs/small.txt
SOURCE_POLICY_ROOT="$budget_repo" bash "$root/ci/source-policy.sh" >/dev/null
budget_expect_failure() {
  local expected="$1" report
  if report="$(SOURCE_POLICY_ROOT="$budget_repo" bash "$root/ci/source-policy.sh" 2>&1)"; then
    echo 'TEST_FAILURE: oversized tracked source unexpectedly passed' >&2
    exit 1
  fi
  grep -Fq "$expected" <<<"$report" || {
    echo "TEST_FAILURE: wrong source-policy rejection (expected $expected): $report" >&2
    exit 1
  }
}
# Sparse file fixtures keep the adversarial Git repository cheap to create,
# while reporting the actual logical file sizes from stat.
truncate -s 8388609 "$budget_repo/docs/oversized.bin"
git -C "$budget_repo" add docs/oversized.bin
budget_expect_failure 'POLICY_FAILURE: tracked file exceeds 8MiB budget:'
git -C "$budget_repo" rm -q -f -- docs/oversized.bin
SOURCE_POLICY_ROOT="$budget_repo" bash "$root/ci/source-policy.sh" >/dev/null
for i in 1 2 3 4 5; do
  truncate -s 7340032 "$budget_repo/docs/budget-$i.bin"
done
git -C "$budget_repo" add docs/budget-*.bin
budget_expect_failure 'POLICY_FAILURE: tracked tree exceeds 32MiB budget'
git -C "$budget_repo" rm -q -f -- docs/budget-*.bin
SOURCE_POLICY_ROOT="$budget_repo" bash "$root/ci/source-policy.sh" >/dev/null

printf 'SOURCE_POLICY_NEGATIVE_TESTS_PASS scenarios=40\n'
