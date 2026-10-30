#!/usr/bin/env bash
# Host-only, fail-closed index inventory. No compiler, native guest or network execution.
set -euo pipefail
root="${SOURCE_MANIFEST_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
root="$(cd "$root" && pwd -P)"
cd "$root"
# An inherited Git index/object override can hide extra tracked .ores files.
# Bind the audit to this checkout's actual index, objects and worktree.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_SHALLOW_FILE GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM GIT_GRAFT_FILE GIT_REPLACE_REF_BASE GIT_EXEC_PATH GIT_CONFIG
export GIT_CONFIG_COUNT=0 GIT_CONFIG_PARAMETERS='' GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
[[ -d "$root/.git" && ! -L "$root/.git" ]] || {
  echo 'INVENTORY_FAILURE: expected real checkout Git directory' >&2; exit 2;
}
git_safe() { /usr/bin/git -c core.fsmonitor=false --no-replace-objects --git-dir="$root/.git" --work-tree="$root" "$@"; }
[[ "$(git_safe rev-parse --show-toplevel)" == "$root" ]] || {
  echo 'INVENTORY_FAILURE: Git root mismatch' >&2; exit 2;
}
for manifest in ci/oreslang-files.txt ci/pure-contracts.txt; do
  [[ -f "$manifest" && -s "$manifest" && ! -L "$manifest" ]] || {
    echo "INVENTORY_FAILURE: missing or linked manifest: $manifest" >&2; exit 2;
  }
  mode="$(git_safe ls-files --stage -- "$manifest")"
  [[ "$mode" == "100644 "*$'\t'"$manifest" ]] || {
    echo "INVENTORY_FAILURE: manifest is not a tracked regular blob: $manifest" >&2; exit 2;
  }
  LC_ALL=C sort -c -u "$manifest" >/dev/null 2>&1 || {
    echo "INVENTORY_FAILURE: manifest is not sorted and unique: $manifest" >&2; exit 2;
  }
  while IFS= read -r path || [[ -n "$path" ]]; do
    [[ "$path" =~ ^(src|tests)/[a-zA-Z0-9_-]+\.ores$ ]] || {
      echo "INVENTORY_FAILURE: unsafe or unexpected manifest path: $path" >&2; exit 2;
    }
    if [[ "$manifest" == ci/pure-contracts.txt && "$path" != tests/* ]]; then
      echo "INVENTORY_FAILURE: non-test in pure contract manifest: $path" >&2; exit 2;
    fi
  done < "$manifest"
done

index_file="$(/usr/bin/mktemp)"
tracked_file="$(/usr/bin/mktemp)"
trap '/usr/bin/rm -f -- "$index_file" "$tracked_file"' EXIT
# Process substitution loses the producer's failure status. Materialize
# and check the complete canonical index inventory before reading it.
git_safe ls-files -z --cached -- '*.ores' > "$tracked_file" || {
  echo 'INVENTORY_FAILURE: unable to enumerate tracked Oreslang source' >&2; exit 2;
}
[[ -s "$tracked_file" ]] || {
  echo 'INVENTORY_FAILURE: empty tracked Oreslang source inventory' >&2; exit 2;
}
while IFS= read -r -d '' path; do
  [[ "$path" == *.ores ]] || continue
  [[ "$path" =~ ^(src|tests)/[a-zA-Z0-9_-]+\.ores$ ]] || {
    echo "INVENTORY_FAILURE: unclassified Oreslang source: $path" >&2; exit 2;
  }
  mode="$(git_safe ls-files --stage -- "$path")"
  [[ "$mode" == "100644 "*$'\t'"$path" && -f "$path" && -s "$path" && ! -L "$path" ]] || {
    echo "INVENTORY_FAILURE: non-regular, unmerged, missing or empty source: $path" >&2; exit 2;
  }
  printf '%s\n' "$path" >> "$index_file"
done < "$tracked_file"
LC_ALL=C sort -u "$index_file" -o "$index_file"
diff -u "$index_file" ci/oreslang-files.txt || {
  echo 'INVENTORY_FAILURE: tracked .ores set diverges from canonical inventory' >&2; exit 2;
}
diff -u <(grep '^tests/' ci/oreslang-files.txt) ci/pure-contracts.txt || {
  echo 'INVENTORY_FAILURE: pure contract set diverges from source inventory' >&2; exit 2;
}
printf 'SOURCE_INVENTORY_STRUCTURAL_PASS sources=%s contracts=%s\n' \
  "$(wc -l < ci/oreslang-files.txt | tr -d ' ')" \
  "$(wc -l < ci/pure-contracts.txt | tr -d ' ')"
echo 'NOT_EXECUTED: no Oreslang compiler or guest executed'
