#!/usr/bin/env bash
#
# 恢复本 (branch, arch) 的 btrfs loop 镜像缓存，并把它挂到 docker 的数据目录。
# 缓存 = GitHub Release(cache) 上的分片 php.<key>.img.zst.01..NN
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

restored=0
if curl -fsI --retry 2 --max-time 30 "${BASE}.01" >/dev/null 2>&1; then
  echo "restoring cache ${key}"
  if (
    for i in $(seq -w 1 10); do
      curl -fsSL --retry 3 --retry-delay 2 "${BASE}.${i}" || break
    done
  ) | zstdmt -d --long -o "$IMG"; then
    restored=1
  fi
fi

if [ "$restored" -ne 1 ] || [ ! -s "$IMG" ]; then
  echo "no usable cache for ${key}, creating a ${size}-byte image"
  rm -f "$IMG"
  truncate -s "$size" "$IMG"
fi

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

touch "$ROOT/php/.cache-ready"
