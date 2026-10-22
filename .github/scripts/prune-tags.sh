#!/usr/bin/env bash
#
# 删除构建过程中推送的中间 tag：<branch>-<archc>-<run_id>（调试模式带 debug- 前缀）。
#
# manifest.sh 在合并成功后会逐个删除本分支的中间 tag，但只要运行被取消、prepare 失败、
# 或合并前就失败，这些 tag 就会永久留在 Docker Hub 上（实测泄漏过 114 个）。
# 本脚本作为兜底：每次运行结束时清掉所有中间 tag。
#
# 用法：
#   prune-tags.sh            删除除本次运行以外的中间 tag
#   prune-tags.sh --all      删除所有中间 tag（运行结束、产物已合并后使用）
#   prune-tags.sh --dry-run  只列出待删除的 tag（无需凭据）
#
# 环境：RUN_TAG（当前 run_id）、DOCKER_HUB_USERNAME、DOCKER_HUB_PASSWORD
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=${IMAGE:-tofuliang/docker-php-openresty}
IMAGE_ORG=${IMAGE%%/*}
IMAGE_REPO=${IMAGE##*/}
API="https://hub.docker.com/v2/repositories/${IMAGE_ORG}/${IMAGE_REPO}/tags"

keep_current=1
dry_run=0
for arg in "$@"; do
  case "$arg" in
    --all) keep_current=0 ;;
    --dry-run) dry_run=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# <branch>-<archc>-<run_id>，调试模式为 debug-<branch>-<archc>-<run_id>
temp_re='^(debug-)?[A-Za-z0-9._-]+-linux_[a-z0-9_]+-[0-9]+$'

# 先完整收集再删除：边翻页边删除会因为结果集变化而漏掉条目
tmp_tags=$(mktemp)
trap 'rm -f "$tmp_tags"' EXIT
url="${API}/?page_size=100"
while [ -n "$url" ] && [ "$url" != "null" ]; do
  page=$(curl -fsS "$url") || break
  echo "$page" | jq -r --arg re "$temp_re" '.results[] | select(.name | test($re)) | .name' >> "$tmp_tags"
  url=$(echo "$page" | jq -r '.next // empty')
done

hub_token=""
if [ "$dry_run" = 0 ]; then
  if [ -z "${DOCKER_HUB_USERNAME:-}" ] || [ -z "${DOCKER_HUB_PASSWORD:-}" ]; then
    echo "::warning::DOCKER_HUB_USERNAME/DOCKER_HUB_PASSWORD 未设置，跳过中间 tag 清理"
    exit 0
  fi
  hub_token=$(curl -fsS -H 'Content-Type: application/json' -X POST \
    -d "{\"username\":\"${DOCKER_HUB_USERNAME}\",\"password\":\"${DOCKER_HUB_PASSWORD}\"}" \
    https://hub.docker.com/v2/users/login/ | jq -r '.token // empty')
  if [ -z "$hub_token" ]; then
    echo "::warning::Docker Hub 登录失败，跳过中间 tag 清理"
    exit 0
  fi
fi

deleted=0
kept=0
failed=0
while read -r tag; do
  [ -n "$tag" ] || continue
  if [ "$keep_current" = 1 ] && [ -n "${RUN_TAG:-}" ] && [[ "$tag" == *"-${RUN_TAG}" ]]; then
    kept=$((kept + 1))
    continue
  fi
  if [ "$dry_run" = 1 ]; then
    echo "would delete ${tag}"
    deleted=$((deleted + 1))
    continue
  fi
  if curl -fsS -o /dev/null -X DELETE -H "Authorization: JWT ${hub_token}" "${API}/${tag}/"; then
    echo "deleted ${tag}"
    deleted=$((deleted + 1))
  else
    echo "::warning::failed to delete intermediate tag ${tag}"
    failed=$((failed + 1))
  fi
done < "$tmp_tags"

if [ "$dry_run" = 1 ]; then
  echo "dry-run: 待删除 ${deleted} 个，保留 ${kept} 个（本次运行）"
else
  echo "清理完成：删除 ${deleted} 个，保留 ${kept} 个，失败 ${failed} 个"
fi
[ "$failed" = 0 ]
