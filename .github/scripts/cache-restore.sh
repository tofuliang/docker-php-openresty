#!/usr/bin/env bash
#
# 恢复本 (branch, arch) 的 btrfs loop 镜像缓存，并把它挂到 docker 的数据目录。
#
# 缓存由 cache-save.sh 写成 release(cache) 上的两段结构：
#   php.<key>.img.zst.current        指针，内容为当前代号
#   php.<key>.img.zst.<gen>.NN       该代号的分片
# 早期没有指针的 php.<key>.img.zst.NN 仍然可以被恢复。
#
# 环境：GITHUB_REPOSITORY、GITHUB_ENV、IMAGE_SIZE（默认 25g）
set -euo pipefail

key=${1:?cache key is required}
ROOT=${CACHE_ROOT:-/mnt}
IMG="$ROOT/php.img"
REPO=${GITHUB_REPOSITORY:?}
BASE="https://github.com/${REPO}/releases/download/cache/php.${key}.img.zst"

size_spec=${IMAGE_SIZE:-25g}
case "$size_spec" in
  *[gG]) WANT_BYTES=$(( ${size_spec%[gG]} * 1024 * 1024 * 1024 )) ;;
  *[mM]) WANT_BYTES=$(( ${size_spec%[mM]} * 1024 * 1024 )) ;;
  *) WANT_BYTES=$size_spec ;;
esac

sudo mkdir -p "$ROOT"
sudo chown -R "$(id -un)":"$(id -gn)" "$ROOT"

# 先停 docker/containerd，避免它们继续写数据目录
sudo systemctl stop docker.socket docker.service containerd.service 2>/dev/null || true
sleep 3

avail=$(df -B1 --output=avail "$ROOT" | tail -1)
size=$WANT_BYTES
max=$((avail - 4 * 1024 * 1024 * 1024))
[ "$size" -gt "$max" ] && size=$max
if [ "$size" -lt "${MIN_IMAGE_BYTES:-8589934592}" ]; then
  echo "::error::$ROOT has only $((avail / 1073741824)) GiB free, cannot host the cache image"
  exit 1
fi

# 流式下载某一代的全部分片；分片缺失时 curl 失败，管道以 zstd 的失败告终。
# 分片上限 99 片（2000 MiB/片，约 190 GiB 压缩后），远超实际用量。
fetch_chunks() {
  rm -f "$IMG"
  (
    for i in $(seq -w 1 99); do
      curl -fsSL --retry 3 --retry-delay 2 "${BASE}.$1${i}" || break
    done
  ) | zstdmt -d --long -o "$IMG"
}

restored=0
gen=$(curl -fsSL --retry 2 --max-time 30 "${BASE}.current" 2>/dev/null | tr -cd '0-9' || true)
if [ -n "$gen" ]; then
  echo "restoring cache ${key} (generation ${gen})"
  if fetch_chunks "${gen}."; then
    restored=1
  else
    echo "::warning::generation ${gen} is unreadable, treating it as absent"
  fi
fi

if [ "$restored" -ne 1 ] && curl -fsI --retry 2 --max-time 30 "${BASE}.01" >/dev/null 2>&1; then
  echo "restoring legacy cache ${key} (no generation pointer)"
  if fetch_chunks ""; then
    restored=1
  fi
fi

if [ "$restored" -ne 1 ] || [ ! -s "$IMG" ]; then
  echo "no usable cache for ${key}, creating a ${size}-byte image"
  rm -f "$IMG"
  truncate -s "$size" "$IMG"
  sudo mkfs.btrfs -f -M "$IMG"
fi

# 允许同一 runner 上重跑（重试/复跑步骤）：先清掉残留的挂载与 loop
sudo umount /var/lib/docker /var/lib/containerd 2>/dev/null || true
sudo umount "$ROOT/php" 2>/dev/null || true
while read -r dev _; do
  [ -n "$dev" ] && sudo losetup -d "${dev%%:}" 2>/dev/null || true
done < <(sudo losetup -j "$IMG" 2>/dev/null || true)

LOOP=""
mount_image() {
  LOOP=$(sudo losetup -f --show -P "$IMG") || return 1
  sudo mkdir -p "$ROOT/php"
  sudo mount -o nossd,compress=zstd "$LOOP" "$ROOT/php"
}

if ! mount_image; then
  echo "cache image is not mountable, recreating"
  [ -n "$LOOP" ] && sudo losetup -d "$LOOP" 2>/dev/null || true
  sudo rm -f "$IMG"
  truncate -s "$size" "$IMG"
  sudo mkfs.btrfs -f -M "$IMG"
  mount_image
fi

echo "LOOP_DEVICE=$LOOP" >>"$GITHUB_ENV"

sudo mkdir -p "$ROOT/php/docker" "$ROOT/php/containerd" /var/lib/docker /var/lib/containerd
sudo chown -R "$(id -un)":"$(id -gn)" "$ROOT/php"
sudo mount --bind "$ROOT/php/docker" /var/lib/docker
sudo mount --bind "$ROOT/php/containerd" /var/lib/containerd
sudo systemctl start docker.socket docker.service

for _ in $(seq 1 30); do
  docker info >/dev/null 2>&1 && break
  sleep 2
done
docker info >/dev/null || {
  echo "::error::docker did not come back after restoring ${key}"
  exit 1
}

# 镜像里可能残留上一次的 buildx 容器，而 ~/.docker 是新的；残留容器只会让
# `buildx create` 撞名。BuildKit 的缓存在 volume 里，删容器不会丢缓存。
docker rm -f buildx_buildkit_builder0 >/dev/null 2>&1 || true

touch "$ROOT/php/.cache-ready"
