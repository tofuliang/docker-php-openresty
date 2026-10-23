#!/usr/bin/env bash
#
# 把每个分支本次运行构建出的 <branch>-<archc>-<RUN_TAG> 镜像合成多架构 manifest：
#   IMAGE:<branch>            （滚动 tag）
#   IMAGE:<branch>-<version>  （版本 tag，取不到版本就跳过）
# 任一架构缺失时不覆盖已有 manifest，并让 job 失败。
#
# tag 里带 RUN_TAG，所以上一次运行遗留的架构镜像不可能被当成这次的产物；
# 合并成功后删除本 run 的中间 tag。
#
# 环境：RUN_TAG（<run_id>-<run_attempt>）、DOCKER_HUB_*（用于删除 tag）
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CONFIG="$ROOT/.github/branches.json"
IMAGE=${IMAGE:-tofuliang/docker-php-openresty}
IMAGE_ORG=${IMAGE%%/*}
IMAGE_REPO=${IMAGE##*/}
source "$ROOT/.github/scripts/arch.sh"

branches=("$@")
if [ ${#branches[@]} -eq 0 ]; then
  echo "no branches to merge"
  exit 0
fi
: "${RUN_TAG:?RUN_TAG is required}"

hub_token=""
if [ -n "${DOCKER_HUB_USERNAME:-}" ] && [ -n "${DOCKER_HUB_PASSWORD:-}" ]; then
  hub_token=$(curl -fsS -H 'Content-Type: application/json' -X POST \
    -d "{\"username\":\"${DOCKER_HUB_USERNAME}\",\"password\":\"${DOCKER_HUB_PASSWORD}\"}" \
    https://hub.docker.com/v2/users/login/ | jq -r '.token // empty')
  [ -n "$hub_token" ] || echo "::warning::Docker Hub login failed, intermediate tags will be left behind"
fi

delete_tag() {
  local tag=$1
  [ -n "$hub_token" ] || return 0
  curl -fsS -o /dev/null -X DELETE -H "Authorization: JWT ${hub_token}" \
    "https://hub.docker.com/v2/repositories/${IMAGE_ORG}/${IMAGE_REPO}/tags/${tag}/" ||
    echo "::warning::failed to delete intermediate tag ${tag}"
}

status=0
for branch in "${branches[@]}"; do
  mapfile -t arches < <(jq -r --arg b "$branch" '.[$b].arches[]' "$CONFIG")
  images=()
  missing=()
  for arch in "${arches[@]}"; do
    tag="${branch}-$(archc_of "$arch")-${RUN_TAG}"
    if docker buildx imagetools inspect "${IMAGE}:${tag}" >/dev/null 2>&1; then
      images+=("${IMAGE}:${tag}")
    else
      missing+=("$arch")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "::error::${branch} incomplete, missing: ${missing[*]}"
    status=1
    continue
  fi

  version=$("$ROOT/.github/scripts/version.sh" "$branch" || true)
  tags=(-t "${IMAGE}:${branch}")
  if [ -n "$version" ]; then
    tags+=(-t "${IMAGE}:${branch}-${version}")
    echo "merging ${branch} (${version}): ${arches[*]}"
  else
    echo "merging ${branch}: ${arches[*]}"
  fi

  if ! docker buildx imagetools create "${tags[@]}" "${images[@]}"; then
    echo "::error::failed to create manifest for ${branch}"
    status=1
    continue
  fi

  docker buildx imagetools inspect "${IMAGE}:${branch}" | head -12
  for arch in "${arches[@]}"; do
    delete_tag "${branch}-$(archc_of "$arch")-${RUN_TAG}"
  done
done

exit "$status"
