#!/usr/bin/env bash
#
# 输出分支对应的版本号（php 取 PHP_URL，openresty 取 RESTY_VERSION），
# 用于生成 <branch>-<version> 形式的 tag。取不到就输出空。
set -euo pipefail

branch=${1:?branch is required}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
dockerfile="$ROOT/$branch/Dockerfile"
[ -f "$dockerfile" ] || exit 1

case "$branch" in
  php[0-9]*)
    awk -F'"' '/^ARG PHP_URL=/{print $2; exit}' "$dockerfile" |
      grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
    ;;
  openresty*)
    awk -F'"' '/^ARG RESTY_VERSION=/{print $2; exit}' "$dockerfile" || true
    ;;
esac
