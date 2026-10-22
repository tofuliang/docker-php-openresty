#!/usr/bin/env bash
#
# 删除 release(cache) 中不再被 branches.json 引用的缓存。
#   prune-cache.sh            # 只列出，不删除
#   prune-cache.sh --apply    # 真正删除
#
# 允许的 key（与 build.yml 的缓存 key 完全一致）：
#   mode=multi   -> <branch>
#   mode=single  -> <branch>-<archc>，archc 来自 .github/scripts/arch.sh
#
# 环境：GITHUB_REPOSITORY、REPO_TOKEN（或 GITHUB_TOKEN）
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
REPO=${GITHUB_REPOSITORY:?}
TOKEN=${REPO_TOKEN:-}
apply=0
[ "${1:-}" = "--apply" ] && apply=1

if [ -z "$TOKEN" ]; then
  echo "::error::REPO_TOKEN is required to inspect release assets"
  exit 1
fi

source "$ROOT/.github/scripts/arch.sh"
source "$ROOT/.github/scripts/cache-lib.sh"

allowed_file=$(mktemp)
trap 'rm -f "$allowed_file"' EXIT

if ! rows_output=$(jq -r 'to_entries[] | "\(.key)\t\(.value.mode // "single")\t\(.value.arches | join(" "))"' \
  "$ROOT/.github/branches.json"); then
  echo "::error::invalid .github/branches.json"
  exit 1
fi
mapfile -t rows <<<"$rows_output"
keys=()
for row in "${rows[@]}"; do
  IFS=$'\t' read -r branch mode arches <<<"$row"
  if [ "$mode" = "multi" ]; then
    keys+=("$branch")
  else
    for arch in $arches; do
      archc=$(archc_of "$arch") || {
        echo "::error::unknown arch '${arch}' for '${branch}'"
        exit 1
      }
      keys+=("${branch}-${archc}")
    done
  fi
done
if [ ${#keys[@]} -eq 0 ]; then
  echo "::error::no cache keys derived from branches.json, refusing to prune"
  exit 1
fi
printf '%s\n' "${keys[@]}" | sort -u >"$allowed_file"

allowed=$(grep -c . "$allowed_file" || true)
echo "configured cache keys: ${allowed}"

rid=$(release_id) || exit 1
if [ -z "$rid" ]; then
  echo "no 'cache' release, nothing to prune"
  exit 0
fi

assets=$(list_assets "$rid") || exit 1

stale=0
freed=0
while IFS=$'\t' read -r id name size; do
  case "$name" in
    php.*.img.zst.*) ;;
    *) continue ;;
  esac
  key=${name#php.}
  key=${key%.img.zst.*}
  # 只认新格式：<key>.current 或 <key>.<gen>.<NN>；旧流水线的 <key>.NN 一律删除
  case "$name" in
    php."${key}".img.zst.current | php."${key}".img.zst.[0-9]*.[0-9]*) ;;
    *)
      echo "stale: ${name} (${size} bytes, legacy format)"
      stale=$((stale + 1))
      freed=$((freed + size))
      if [ "$apply" -eq 1 ]; then
        curl -fsS -o /dev/null -X DELETE -H "$AUTH" "$API/releases/assets/${id}" ||
          echo "::warning::failed to delete asset ${id} (${name})"
      fi
      continue
      ;;
  esac
  grep -qxF "$key" "$allowed_file" && continue

  echo "stale: ${name} (${size} bytes, key=${key})"
  stale=$((stale + 1))
  freed=$((freed + size))
  if [ "$apply" -eq 1 ]; then
    curl -fsS -o /dev/null -X DELETE -H "$AUTH" "$API/releases/assets/${id}" ||
      echo "::warning::failed to delete asset ${id} (${name})"
  fi
done <<<"$assets"

summary="stale cache assets: ${stale}, reclaimable: $((freed / 1048576)) MiB"
if [ "$apply" -eq 1 ]; then
  echo "pruned; ${summary}"
else
  echo "dry-run; ${summary} (pass --apply to delete)"
fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '%s cache assets not in branches.json: %s, %s MiB\n' \
    "$([ "$apply" -eq 1 ] && echo pruned || echo stale)" "$stale" "$((freed / 1048576))" >>"$GITHUB_STEP_SUMMARY"
fi
exit 0
