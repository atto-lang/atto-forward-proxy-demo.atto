#!/usr/bin/env bash
# Host-only, fail-closed index inventory. No compiler, native guest or network execution.
set -euo pipefail
root="${SOURCE_MANIFEST_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
root="$(cd "$root" && pwd -P)"
cd "$root"
[[ "$(git rev-parse --show-toplevel)" == "$root" ]] || {
  echo 'INVENTORY_FAILURE: Git root mismatch' >&2; exit 2;
}
for manifest in ci/oreslang-files.txt ci/pure-contracts.txt; do
  [[ -f "$manifest" && -s "$manifest" && ! -L "$manifest" ]] || {
    echo "INVENTORY_FAILURE: missing or linked manifest: $manifest" >&2; exit 2;
  }
  mode="$(git ls-files --stage -- "$manifest")"
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

index_file="$(mktemp)"
trap 'rm -f "$index_file"' EXIT
while IFS= read -r -d '' path; do
  [[ "$path" == *.ores ]] || continue
  [[ "$path" =~ ^(src|tests)/[a-zA-Z0-9_-]+\.ores$ ]] || {
    echo "INVENTORY_FAILURE: unclassified Oreslang source: $path" >&2; exit 2;
  }
  mode="$(git ls-files --stage -- "$path")"
  [[ "$mode" == "100644 "*$'\t'"$path" && -f "$path" && -s "$path" && ! -L "$path" ]] || {
    echo "INVENTORY_FAILURE: non-regular, unmerged, missing or empty source: $path" >&2; exit 2;
  }
  printf '%s\n' "$path" >> "$index_file"
done < <(git ls-files -z -- '*.ores')
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
