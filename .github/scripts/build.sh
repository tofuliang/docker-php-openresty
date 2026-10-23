#!/usr/bin/env bash
#
# 构建单个分支。
#   build.sh <branch>            # 多架构（用于 php-builder / php-modern）
#   build.sh <branch> <archc>    # 单架构，archc 形如 linux_arm64
#
# 构建缓存由 cache-restore.sh / cache-save.sh 维护的 btrfs loop 镜像承载，
# 这里只负责 buildx 参数。
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
  case "$archc" in
    linux_amd64) platform=linux/amd64 ;;
    linux_386) platform=linux/386 ;;
    linux_arm64) platform=linux/arm64 ;;
    linux_arm_v7) platform=linux/arm/v7 ;;
    *) echo "unknown archc: $archc" >&2; exit 1 ;;
  esac
  tag="${branch}-${archc}"
else
  platform="linux/amd64,linux/386,linux/arm64,linux/arm/v7"
  tag="${branch}"
fi

echo "building ${IMAGE}:${tag} for ${platform}"
docker buildx build \
  --platform "$platform" \
  "${build_args[@]}" \
  --provenance=false --sbom=false \
  -t "${IMAGE}:${tag}" \
  --push \
  "${ROOT}/${branch}"
