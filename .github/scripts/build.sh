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
# 全量重建会打满 Docker Hub 的拉取配额（toomanyrequests），这类限流等一会儿就好，自动重试。
build_log=$(mktemp)
trap 'rm -f "$build_log"' EXIT
attempt=1
while true; do
  set +e
  docker buildx build \
    --platform "$platform" \
    "${build_args[@]}" \
    --provenance=false --sbom=false \
    -t "${IMAGE}:${tag}" \
    --push \
    "${ROOT}/${branch}" >"$build_log" 2>&1
  rc=$?
  set -e
  tail -40 "$build_log"
  [ "$rc" = 0 ] && break
  if grep -qiE 'toomanyrequests|pull rate limit' "$build_log" && [ "$attempt" -lt 4 ]; then
    echo "::warning::Docker Hub 拉取限流，600s 后重试（第 ${attempt} 次失败）"
    attempt=$((attempt + 1))
    sleep 600
    continue
  fi
  echo "::error::build failed (rc=$rc)"
  exit "$rc"
done

# 启动自检：s6 初始化失败（例如系统二进制被 upx 压坏）在这里立刻暴露，
# 不用等用户拉镜像才发现。builder 镜像没有 /init，跳过；runner 跑不了的平台也跳过。
# 多架构构建（php-modern 等）时 platform 是逗号列表，取 runner 自身架构来做自检
smoke_platform="$platform"
case "$platform" in
  *,*) smoke_platform="linux/$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" ;;
esac
# 刚 push 完 manifest 可能还在传播，先显式拉取并重试探测，避免误判
has_init=no
for _ in 1 2 3; do
  docker pull -q --platform "$smoke_platform" "${IMAGE}:${tag}" >/dev/null 2>&1 || true
  if docker run --rm --platform "$smoke_platform" --entrypoint sh "${IMAGE}:${tag}" -c '[ -x /init ]' >/dev/null 2>&1; then
    has_init=yes
    break
  fi
  sleep 20
done
# Dockerfile 声明了 ENTRYPOINT /init 就必须真的有 /init：
# php-modern 曾因 apk 失败被 '|| true' 吞掉、s6 安装整段跳过，镜像起不来却构建成功。
if [ "$has_init" = no ] && grep -qE '^ENTRYPOINT.*/init' "${ROOT}/${branch}/Dockerfile"; then
  echo "::error::${IMAGE}:${tag} 缺少 /init（Dockerfile 的 ENTRYPOINT 依赖它）"
  exit 1
fi
if [ "$has_init" = no ]; then
  echo "镜像无 /init（builder 等），跳过启动自检"
else
  smoke_log=$(mktemp)
  timeout 60 docker run --rm --platform "$smoke_platform" "${IMAGE}:${tag}" >"$smoke_log" 2>&1 || true
  if grep -qiE 'exec format error|no matching manifest for' "$smoke_log"; then
    echo "::warning::runner 无法运行 ${smoke_platform}，跳过启动自检"
  elif grep -qiE 's6-overlay-suexec: fatal|applet not found|segmentation fault' "$smoke_log"; then
    echo "::error::${IMAGE}:${tag} 启动自检失败："
    tail -20 "$smoke_log"
    rm -f "$smoke_log"
    exit 1
  elif ! grep -qE 's6-rc: info: service|\[s6-init\]|\[cont-init\.d\]' "$smoke_log"; then
    echo "::error::${IMAGE}:${tag} 启动自检未看到 s6 服务启动日志："
    tail -20 "$smoke_log"
    rm -f "$smoke_log"
    exit 1
  else
    echo "启动自检通过"
  fi
  rm -f "$smoke_log"
fi
