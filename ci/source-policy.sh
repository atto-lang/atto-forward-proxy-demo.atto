#!/usr/bin/env bash
# Fail-closed tracked-source policy; host-only, no Oreslang guest execution.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# SOURCE_POLICY_ROOT is an isolated-test fixture override only. A SHA check
# proves the selected Git commit, not that this script audited the checkout
# from which it was invoked. Two worktrees can share HEAD but differ in bytes.
if [[ -n "${EXPECTED_DEMO_SHA:-}" && -n "${SOURCE_POLICY_ROOT:-}" ]]; then
  echo 'POLICY_FAILURE: SHA-pinned audit cannot redirect SOURCE_POLICY_ROOT' >&2
  exit 2
fi
root="${SOURCE_POLICY_ROOT:-$repo_root}"
root="$(cd "$root" && pwd -P)"
cd "$root"
# Reject redirected Git index/object inventories from reused CI environments.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_SHALLOW_FILE GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM GIT_GRAFT_FILE GIT_REPLACE_REF_BASE GIT_EXEC_PATH GIT_CONFIG
export GIT_CONFIG_COUNT=0 GIT_CONFIG_PARAMETERS='' GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
[[ -d "$root/.git" && ! -L "$root/.git" ]] || { echo "POLICY_FAILURE: expected a real checkout Git directory" >&2; exit 2; }
git_safe() { /usr/bin/git -c core.fsmonitor=false -c core.filemode=true --no-replace-objects --git-dir="$root/.git" --work-tree="$root" "$@"; }
[[ "$(git_safe rev-parse --show-toplevel)" == "$root" ]] || { echo "POLICY_FAILURE: Git repository root mismatch" >&2; exit 2; }
if [[ -n "${EXPECTED_DEMO_SHA:-}" ]]; then
  [[ "${EXPECTED_DEMO_SHA}" =~ ^[a-f0-9]{40}$ ]] || { echo "POLICY_FAILURE: invalid expected head" >&2; exit 2; }
  [[ "$(git_safe rev-parse HEAD)" == "$EXPECTED_DEMO_SHA" ]] || { echo "POLICY_FAILURE: mismatched head" >&2; exit 2; }
  # A pinned HEAD alone does not authenticate its index or worktree.
  # A deleted HEAD path, staged addition, chmod, or ignored extra source must
  # never be able to disappear from the exact-source inventory.
  git_safe diff --no-ext-diff --cached --quiet HEAD -- || {
    echo "POLICY_FAILURE: SHA-pinned audit has staged changes against HEAD" >&2; exit 2;
  }
  git_safe diff --no-ext-diff --quiet HEAD -- || {
    echo "POLICY_FAILURE: SHA-pinned audit has modified tracked files" >&2; exit 2;
  }
  # Without --exclude-standard, ls-files --others includes ignored paths:
  # ignored inputs must not escape an exact-source checkout audit.
  untracked_bytes="$(git_safe ls-files --others -z -- | /usr/bin/wc -c)" || {
    echo "POLICY_FAILURE: unable to enumerate untracked files" >&2; exit 2;
  }
  [[ "$untracked_bytes" -eq 0 ]] || {
    echo "POLICY_FAILURE: SHA-pinned audit has untracked or ignored files" >&2; exit 2;
  }
fi
if [[ -e SOURCE_REF || -L SOURCE_REF ]] || git_safe ls-files --error-unmatch -- SOURCE_REF >/dev/null 2>&1; then
  [[ ! -L SOURCE_REF && -f SOURCE_REF ]] &&
    git_safe ls-files --error-unmatch -- SOURCE_REF >/dev/null 2>&1 || {
    echo 'POLICY_FAILURE: symlinked or untracked SOURCE_REF' >&2; exit 2;
  }
  # SOURCE_REF is an inert commit pin, never an executable or a gitlink.
  # An executable stage-0 index entry can otherwise pass the general file
  # inventory even when its bytes are a valid 40-hex provenance token.
  [[ "$(git_safe ls-files --stage -- SOURCE_REF)" == "100644 "* ]] || {
    echo 'POLICY_FAILURE: SOURCE_REF must be a tracked 100644 regular blob' >&2; exit 2;
  }
  [[ "$(wc -l < SOURCE_REF)" -eq 1 ]] && grep -Eq '^[a-f0-9]{40}$' SOURCE_REF && [[ "$(wc -c < SOURCE_REF)" -eq 41 ]] || {
    echo "POLICY_FAILURE: SOURCE_REF requires exactly 40 lowercase hex characters and newline" >&2; exit 2;
  }
fi
mode="${SOURCE_POLICY_MODE:-strict}"
[[ "$mode" == strict || "$mode" == rest-legacy ]] || { echo "POLICY_FAILURE: unknown mode" >&2; exit 2; }
# A SHA-pinned production audit must not enable migration-only Python exceptions.
# The exact-head workflow must always apply strict source admission.
if [[ -n "${EXPECTED_DEMO_SHA:-}" && "$mode" != strict ]]; then
  echo 'POLICY_FAILURE: SHA-pinned source policy requires strict mode' >&2
  exit 2
fi
# Do not mask Git failures behind process substitution: both inventories must
# be produced successfully from the actual checkout index, and be nonempty.
stage_list="$(/usr/bin/mktemp)" || exit 2
tracked_list="$(/usr/bin/mktemp)" || exit 2
trap '/usr/bin/rm -f -- "$stage_list" "$tracked_list"' EXIT
git_safe ls-files --stage -z > "$stage_list" || { echo "POLICY_FAILURE: failed staged inventory" >&2; exit 2; }
git_safe ls-files -z --cached > "$tracked_list" || { echo "POLICY_FAILURE: failed tracked inventory" >&2; exit 2; }
[[ -s "$stage_list" && -s "$tracked_list" ]] || { echo "POLICY_FAILURE: empty tracked index" >&2; exit 2; }
# Reject all tracked symlinks, gitlinks, and unmerged index entries.
# Metadata is the Git index; filename extensions alone are insufficient.
while IFS= read -r -d '' entry; do
  [[ "$entry" == *$'\t'* ]] || {
    echo 'POLICY_FAILURE: malformed index entry' >&2; exit 2;
  }
  meta="${entry%%$'\t'*}"
  path="${entry#*$'\t'}"
  read -r filemode object stage <<< "$meta"
  [[ "$stage" == 0 ]] || {
    echo "POLICY_FAILURE: unmerged index entry: $path" >&2; exit 2;
  }
  [[ "$filemode" == 100644 || "$filemode" == 100755 ]] || {
    echo "POLICY_FAILURE: symlink, gitlink or unsupported file mode: $path ($filemode)" >&2; exit 2;
  }
  [[ -f "$path" && ! -L "$path" ]] || {
    echo "POLICY_FAILURE: tracked file absent or replaced: $path" >&2; exit 2;
  }
  # A regular file reached through a symlinked parent directory is still
  # outside the audited checkout, even when its raw blob matches the index.
  [[ "$(/usr/bin/realpath -e -- "$path")" == "$root/$path" ]] || {
    echo "POLICY_FAILURE: tracked file escapes checkout through parent path: $path" >&2; exit 2;
  }
  # A staged blob may differ from a harmless-looking worktree file. Verify
  # the exact raw bytes that Git would commit, without invoking clean filters.
  actual_blob="$(git_safe hash-object --no-filters -- "$path")" || {
    echo "POLICY_FAILURE: unable to hash tracked file: $path" >&2; exit 2;
  }
  [[ "$actual_blob" == "$object" ]] || {
    echo "POLICY_FAILURE: staged blob differs from audited worktree: $path" >&2; exit 2;
  }
done < "$stage_list"
count=0
while IFS= read -r -d '' path; do
  count=$((count+1))
  (( count <= 50000 )) || { echo "POLICY_FAILURE: file budget" >&2; exit 2; }
  if [[ -L "$path" ]]; then
    case "${path,,}" in
      *.ores|*.py|*.pyi|*.ipynb)
        echo "POLICY_FAILURE: symlinked source: $path" >&2; exit 2 ;;
    esac
  fi
  allowed=0
  if [[ "$mode" == rest-legacy ]]; then
    case "$path" in
      scripts/benchmark.py|scripts/generate-routes.py|tests/core_diagnostics.py|tests/integration.py|tests/native_distribution.py|tests/test_route_publication.py)
        allowed=1
        printf 'LEGACY_PYTHON_NONCOMPLIANT existing_path=%s\n' "$path"
        ;;
    esac
  fi
  case "${path,,}" in
    *.py|*.pyi|*.ipynb)
      if (( ! allowed )); then
        printf 'POLICY_FAILURE: Python source is not permitted: %s\n' "$path" >&2
        exit 2
      fi
      ;;
  esac
  if (( ! allowed )) && [[ -f "$path" ]]; then
    IFS= read -r firstline < "$path" || true
    # GNU env -S expands ${NAME} using the execution environment before
    # resolving its interpreter. A variable can name Python without any
    # literal python token appearing in the tracked shebang; fail closed.
    if [[ "$firstline" == '#!'* && "$firstline" == *'${'* ]]; then
      printf 'POLICY_FAILURE: variable-expanded shebang is not permitted: %s\n' "$path" >&2
      exit 2
    fi
    # GNU env -S treats \_ as a word separator. Erasing its backslash
    # leaves _python3, which bypasses a literal interpreter regex even though
    # Linux executes python3. Reject escape separators rather than guessing
    # whether they are active inside quotes.
    if [[ "$firstline" == '#!'* && "$firstline" == *'\_'* ]]; then
      printf 'POLICY_FAILURE: escaped shebang separator is not permitted: %s\n' "$path" >&2
      exit 2
    fi
    # env -S accepts quoted and concatenated interpreter tokens. Normalize
    # their shell-like quoting before testing, or 'python3' evades the guard.
    normalized_shebang="${firstline//\"/}"
    normalized_shebang="${normalized_shebang//\'/}"
    normalized_shebang="${normalized_shebang//\\/}"
    if [[ "$normalized_shebang" =~ ^\#!.*(^|[/[:space:]])(python|pypy)[[:alnum:]_.+-]*([[:space:]]|$) ]]; then
      printf 'POLICY_FAILURE: Python interpreter shebang: %s\n' "$path" >&2
      exit 2
    fi
  fi
done < "$tracked_list"
printf 'SOURCE_POLICY_STRUCTURAL_PASS tracked_files=%s mode=%s\n' "$count" "$mode"
if [[ "$mode" == rest-legacy ]]; then
  echo 'LEGACY_PYTHON_NONCOMPLIANT: complete Rust replacement remains required'
fi
echo 'NOT_EXECUTED: this gate did not invoke an Oreslang compiler or guest'
