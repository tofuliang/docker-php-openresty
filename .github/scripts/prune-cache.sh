#!/usr/bin/env bash
#
# 删除 release(cache) 中不再被 branches.json 引用的分片缓存。
#   prune-cache.sh            # 只列出，不删除
#   prune-cache.sh --apply    # 真正删除
#
# 允许的 key：
#   mode=multi   -> <branch>
#   mode=single  -> <branch>-<archc>   （每个 arches 条目一个）
#
# 环境：GITHUB_REPOSITORY、REPO_TOKEN（或 GITHUB_TOKEN）
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
REPO=${GITHUB_REPOSITORY:?}
TOKEN=${REPO_TOKEN:-${GITHUB_TOKEN:-}}
API="https://api.github.com/repos/${REPO}"
AUTH="Authorization: Token ${TOKEN}"
apply=0
[ "${1:-}" = "--apply" ] && apply=1

if [ -z "$TOKEN" ]; then
  echo "::error::REPO_TOKEN is required to inspect release assets"
  exit 1
fi

allowed_file=$(mktemp)
assets_file=$(mktemp)
trap 'rm -f "$allowed_file" "$assets_file"' EXIT

jq -r '
  to_entries[]
  | .key as $branch
  | .value as $spec
  | if $spec.mode == "multi" then $branch
    else ($spec.arches[] | "\($branch)-linux_\(if . == "armv7" then "arm_v7" else . end)")
    end
' "$ROOT/.github/branches.json" | sort -u >"$allowed_file"

allowed=$(wc -l <"$allowed_file" | tr -d ' ')
echo "configured cache keys: ${allowed}"
if [ "$allowed" -eq 0 ]; then
  echo "::error::no cache keys derived from branches.json, refusing to prune"
  exit 1
fi

release_id=$(curl -fsS -H "$AUTH" "$API/releases/tags/cache" | jq -r '.id // empty')
if [ -z "$release_id" ]; then
  echo "no 'cache' release, nothing to prune"
  exit 0
fi

page=1
while :; do
  payload=$(curl -fsS -H "$AUTH" "$API/releases/${release_id}/assets?per_page=100&page=${page}") || break
  count=$(printf '%s' "$payload" | jq '.assets | length')
  [ "${count:-0}" -eq 0 ] && break
  printf '%s' "$payload" | jq -r '.assets[] | [.id, .name, .size] | @tsv' >>"$assets_file"
  [ "$count" -lt 100 ] && break
  page=$((page + 1))
done

stale=0
freed=0
while IFS=$'\t' read -r id name size; do
  case "$name" in
    php.*.img.zst.[0-9]*) ;;
    *) continue ;;
  esac
  key=${name#php.}
  key=${key%.img.zst.*}
  grep -qxF "$key" "$allowed_file" && continue

  echo "stale: ${name} (${size} bytes, key=${key})"
  stale=$((stale + 1))
  freed=$((freed + size))
  if [ "$apply" -eq 1 ]; then
    curl -fsS -o /dev/null -X DELETE -H "$AUTH" "$API/releases/assets/${id}" ||
      echo "::warning::failed to delete asset ${id} (${name})"
  fi
done <"$assets_file"

summary="stale cache assets: ${stale}, reclaimable: $((freed / 1048576)) MiB"
if [ "$apply" -eq 1 ]; then
  echo "pruned; ${summary}"
else
  echo "dry-run; ${summary} (pass --apply to delete)"
fi
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s cache assets not in branches.json: %s, %s MiB\n' \
  "$([ "$apply" -eq 1 ] && echo pruned || echo stale)" "$stale" "$((freed / 1048576))" >>"$GITHUB_STEP_SUMMARY"
exit 0
