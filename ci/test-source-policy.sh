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
printf 'SOURCE_POLICY_NEGATIVE_TESTS_PASS scenarios=29\n'
