#!/usr/bin/env bash
#
# release(cache) 资产 API 的公共函数，cache-save.sh 与 prune-cache.sh 共用。
# 需要环境变量：REPO、TOKEN（有 contents:write 的 token）。
#
# 所有函数都显式区分「没有 release」和「鉴权/网络失败」，
# 后者返回非零，避免把 401 当成「缓存不存在」而静默跳过清理。

API="https://api.github.com/repos/${REPO}"
AUTH="Authorization: Token ${TOKEN}"

# release_id → stdout 输出 id；release 不存在时输出空且返回 0
release_id() {
  local resp code body
  resp=$(curl -sS -H "$AUTH" -w '\n%{http_code}' "$API/releases/tags/cache") || true
  code=${resp##*$'\n'}
  body=${resp%$'\n'*}
  case "$code" in
    200) printf '%s' "$body" | jq -r '.id // empty' ;;
    404) return 0 ;;
    *)
      echo "::error::cannot read release 'cache' (HTTP ${code})" >&2
      return 1
      ;;
  esac
}

# list_assets <release_id> → 每行 "id<TAB>name<TAB>size"，自动翻页。
# 注意：这个端点返回的是裸数组，不是 {"assets": [...]}。
list_assets() {
  local id=$1 page=1 resp code body count
  while :; do
    resp=$(curl -sS -H "$AUTH" -w '\n%{http_code}' \
      "$API/releases/${id}/assets?per_page=100&page=${page}") || true
    code=${resp##*$'\n'}
    body=${resp%$'\n'*}
    if [ "$code" != 200 ]; then
      echo "::error::cannot list release assets (HTTP ${code})" >&2
      return 1
    fi
    count=$(printf '%s' "$body" | jq -r 'if type == "array" then length else "" end' 2>/dev/null)
    case "$count" in
      '' | *[!0-9]*)
        echo "::error::unexpected assets response (expected a JSON array)" >&2
        return 1
        ;;
    esac
    printf '%s' "$body" | jq -r '.[] | [.id, .name, .size] | @tsv'
    [ "$count" -lt 100 ] && break
    page=$((page + 1))
    [ "$page" -gt 50 ] && break
  done
}
