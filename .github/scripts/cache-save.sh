#!/usr/bin/env bash
#
# 保存本 (branch, arch) 的 btrfs loop 镜像缓存。
#
# 顺序保证「上传失败不丢上一份缓存」：
#   1. 上传新代号的全部分片
#   2. 全部分片成功后才替换 current 指针
#   3. 删除其它代号的分片
# 任一步失败都保留旧指针，旧缓存继续可用。
#
# 环境：GITHUB_REPOSITORY、REPO_TOKEN、LOOP_DEVICE（来自 restore）
# 前提：release(cache) 已存在（首次部署需手工创建，restore/构建不依赖它）。
set -uo pipefail

key=${1:?cache key is required}
ROOT=${CACHE_ROOT:-/mnt}
IMG="$ROOT/php.img"
REPO=${GITHUB_REPOSITORY:?}
TOKEN=${REPO_TOKEN:-}

if [ -z "$TOKEN" ]; then
  echo "::error::REPO_TOKEN is required to upload the cache"
  exit 1
fi
if [ ! -f "$IMG" ] || [ ! -f "$ROOT/php/.cache-ready" ]; then
  echo "cache was not prepared in this run, nothing to save"
  exit 0
fi

source "$(cd "$(dirname "$0")" && pwd)/cache-lib.sh"
prefix="php.${key}.img.zst"

docker logout || true
sudo systemctl stop docker.socket docker.service containerd.service 2>/dev/null || true
sleep 5
sudo umount /var/lib/docker 2>/dev/null || true
sudo umount /var/lib/containerd 2>/dev/null || true

# 保留 1G 余量后再把空闲块写零，避免 btrfs 被写满后变只读
trap 'sudo rm -f "$ROOT/php/zerospace"' EXIT TERM INT
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

rid=$(release_id) || exit 1
if [ -z "$rid" ]; then
  echo "::error::release 'cache' not found in ${REPO}"
  exit 1
fi

gen=$(date -u +%s)
rm -f "$ROOT/${prefix}".*
if ! zstdmt -c --long "$IMG" | split --numeric-suffixes=1 --suffix-length=2 -b 2000m - "$ROOT/${prefix}.${gen}."; then
  echo "::error::failed to compress the cache image"
  rm -f "$ROOT/${prefix}.${gen}".*
  exit 1
fi

failed=0
for chunk in "$ROOT/${prefix}.${gen}".*; do
  name=$(basename "$chunk")
  ok=0
  for _ in 1 2 3; do
    if curl -fsS -T "$chunk" -H "$AUTH" -H "Content-Type: application/octet-stream" \
      "https://uploads.github.com/repos/${REPO}/releases/${rid}/assets?name=${name}" >/dev/null; then
      ok=1
      break
    fi
    sleep 5
  done
  [ "$ok" -eq 1 ] || { echo "::warning::failed to upload ${name}"; failed=1; }
done
rm -f "$ROOT/${prefix}.${gen}".*

if [ "$failed" -ne 0 ]; then
  echo "::error::chunk upload failed, previous generation left intact"
  exit 1
fi

assets=$(list_assets "$rid") || exit 1

# 先删旧指针，否则同名资产无法上传
while IFS=$'\t' read -r id name _; do
  [ "$name" = "${prefix}.current" ] || continue
  if ! curl -fsS -o /dev/null -X DELETE -H "$AUTH" "$API/releases/assets/${id}"; then
    echo "::error::cannot replace the generation pointer"
    exit 1
  fi
done <<<"$assets"

printf '%s\n' "$gen" >"$ROOT/current.txt"
if ! curl -fsS -T "$ROOT/current.txt" -H "$AUTH" -H "Content-Type: text/plain" \
  "https://uploads.github.com/repos/${REPO}/releases/${rid}/assets?name=${prefix}.current" >/dev/null; then
  rm -f "$ROOT/current.txt"
  echo "::error::failed to upload the generation pointer, cache not switched"
  exit 1
fi
rm -f "$ROOT/current.txt"

# 删除旧代号，当前代号与指针保留
while IFS=$'\t' read -r id name _; do
  case "$name" in
    "${prefix}."?*) ;;
    *) continue ;;
  esac
  case "$name" in
    "${prefix}.${gen}."* | "${prefix}.current") continue ;;
  esac
  curl -fsS -o /dev/null -X DELETE -H "$AUTH" "$API/releases/assets/${id}" ||
    echo "::warning::failed to delete old asset ${name}"
done <<<"$assets"

echo "uploaded generation ${gen} for ${key}"
