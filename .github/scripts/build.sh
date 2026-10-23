#!/usr/bin/env bash
#
# 构建单个分支。
#   build.sh <branch>            # 多架构（用于 php-builder / php-modern）
#   build.sh <branch> <archc>    # 单架构，archc 形如 linux_arm64
#
# 缓存放在 registry（IMAGE:cache-<branch>[-<archc>]），不再依赖 loop 镜像。
set -euo pipefail

branch=${1:?branch is required}
archc=${2:-}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=${IMAGE:-tofuliang/docker-php-openresty}
JOBS=${JOBS:-$(nproc)}

build_args=(--build-arg "JOBS=${JOBS}" --build-arg "RESTY_J=${JOBS}")
case "$branch" in
  php[0-9]*) build_args+=(--build-arg "BRANCH=${branch#php}") ;;
esac

if [ -n "$archc" ]; then
  platform=""
  case "$archc" in
    linux_amd64) platform=linux/amd64 ;;
    linux_386) platform=linux/386 ;;
    linux_arm64) platform=linux/arm64 ;;
    linux_arm_v7) platform=linux/arm/v7 ;;
    *) echo "unknown archc: $archc" >&2; exit 1 ;;
  esac
  tag="${branch}-${archc}"
  cache="cache-${branch}-${archc}"
else
  platform="linux/amd64,linux/386,linux/arm64,linux/arm/v7"
  tag="${branch}"
  cache="cache-${branch}"
fi

cache_args=()
if docker buildx imagetools inspect "${IMAGE}:${cache}" >/dev/null 2>&1; then
  cache_args+=(--cache-from "type=registry,ref=${IMAGE}:${cache}")
fi

echo "building ${IMAGE}:${tag} for ${platform}"
docker buildx build \
  --platform "$platform" \
  "${build_args[@]}" \
  --provenance=false --sbom=false \
  -t "${IMAGE}:${tag}" \
  "${cache_args[@]}" \
  --cache-to "type=registry,ref=${IMAGE}:${cache},mode=max" \
  --push \
  "${ROOT}/${branch}"
