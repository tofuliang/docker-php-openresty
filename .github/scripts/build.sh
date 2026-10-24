#!/usr/bin/env bash
#
# 构建单个分支。
#   build.sh <branch>            # 多架构（用于 php-builder / php-modern）
#   build.sh <branch> <arch>     # 单架构，arch 取 amd64/386/arm64/armv7
#
# 单架构的镜像 tag 带本 run 的后缀（<branch>-<archc>-<RUN_TAG>），
# 这样 manifest 只会合并本次运行真正构建出来的架构：
# 构失败的架构不会留下旧 tag 被误认为成功。
#
# 构建缓存由 cache-restore.sh / cache-save.sh 维护的 btrfs loop 镜像承载。
set -euo pipefail

branch=${1:?branch is required}
arch=${2:-}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=${IMAGE:-tofuliang/docker-php-openresty}
JOBS=${JOBS:-$(nproc)}
source "$ROOT/.github/scripts/arch.sh"

build_args=(--build-arg "JOBS=${JOBS}" --build-arg "RESTY_J=${JOBS}")
case "$branch" in
  php[0-9]*) build_args+=(--build-arg "BRANCH=${branch#php}") ;;
esac

if [ -n "$arch" ]; then
  info=$(arch_map "$arch") || {
    echo "unknown arch: ${arch}" >&2
    exit 1
  }
  read -r archc platform _ <<<"$info"
  : "${RUN_TAG:?RUN_TAG is required for single-arch builds}"
  tag="${branch}-${archc}-${RUN_TAG}"
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
