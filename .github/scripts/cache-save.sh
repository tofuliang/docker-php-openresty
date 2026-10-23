#!/usr/bin/env bash
#
# 保存本 (branch, arch) 的 btrfs loop 镜像缓存到 GitHub Release(cache)。
# 先清理旧分片，再上传 php.<key>.img.zst.01..NN。
#
# 环境：GITHUB_REPOSITORY、REPO_TOKEN、LOOP_DEVICE（来自 restore）
set -uo pipefail

key=${1:?cache key is required}
ROOT=${CACHE_ROOT:-/mnt}
IMG="$ROOT/php.img"
REPO=${GITHUB_REPOSITORY:?}
TOKEN=${REPO_TOKEN:-${GITHUB_TOKEN:-}}
API="https://api.github.com/repos/${REPO}"
AUTH="Authorization: Token ${TOKEN}"

if [ -z "$TOKEN" ]; then
  echo "::error::REPO_TOKEN is required to upload the cache"
  exit 1
fi
if [ ! -f "$IMG" ] || [ ! -f "$ROOT/php/.cache-ready" ]; then
  echo "cache was not prepared in this run, nothing to save"
  exit 0
fi

docker logout || true
sudo systemctl stop docker.socket docker.service containerd.service 2>/dev/null || true
sleep 5
sudo umount /var/lib/docker 2>/dev/null || true
sudo umount /var/lib/containerd 2>/dev/null || true

# 保留 1G 余量后再把空闲块写零，避免 btrfs 被写满后变只读
sudo mount -o remount,compress=no,nodatacow,nodatasum "$ROOT/php" 2>/dev/null || true
sudo bash -c '
  cd "$1" || exit 0
  avail=$(df -B1 --output=avail . | tail -1)
  echo "zerospace: $((avail / 1048576)) MiB available"
  if [ "${avail:-0}" -gt 1073741824 ]; then
    head -c $((avail - 1073741824)) /dev/zero > zerospace || true
  fi
  sync
  rm -f zerospace || true
' _ "$ROOT/php" || true

sleep 5
sudo umount "$ROOT/php" 2>/dev/null || true
if [ -n "${LOOP_DEVICE:-}" ]; then
  sudo losetup -d "$LOOP_DEVICE" 2>/dev/null || true
fi

release_id=$(curl -fsS -H "$AUTH" "$API/releases/tags/cache" | jq -r '.id // empty')
if [ -z "$release_id" ]; then
  echo "::error::release 'cache' not found in ${REPO}"
  exit 1
fi

# 删除该 key 之前的分片（分页，避免 100 条上限）
page=1
while :; do
  ids=$(curl -fsS -H "$AUTH" "$API/releases/${release_id}/assets?per_page=100&page=${page}" |
    jq -r --arg prefix "php.${key}.img." '.assets[] | select(.name | startswith($prefix)) | .id')
  [ -n "$ids" ] || break
  for id in $ids; do
    curl -fsS -o /dev/null -X DELETE -H "$AUTH" "$API/releases/assets/${id}" ||
      echo "::warning::failed to delete asset ${id}"
  done
done

rm -f "$ROOT"/php."${key}".img.zst.*
zstdmt -c --long "$IMG" | split --numeric-suffixes=1 --suffix-length=2 -b 2000m - "$ROOT/php.${key}.img.zst."

uploaded=0
for chunk in "$ROOT"/php."${key}".img.zst.*; do
  name=$(basename "$chunk")
  for _ in 1 2 3; do
    if curl -fsS -T "$chunk" -H "$AUTH" -H "Content-Type: application/octet-stream" \
      "https://uploads.github.com/repos/${REPO}/releases/${release_id}/assets?name=${name}" >/dev/null; then
      uploaded=$((uploaded + 1))
      break
    fi
    sleep 5
  done
done

rm -f "$ROOT"/php."${key}".img.zst.*
echo "uploaded ${uploaded} chunks for ${key}"
