#!/usr/bin/env bash
#
# 架构映射的唯一来源：arch → "archc platform runner"。
# prepare-matrix.sh / build.sh / manifest.sh / prune-cache.sh 都 source 这个文件，
# 避免像 <branch>-linux_armv7 与 <branch>-linux_arm_v7 这样各写一套。
arch_map() {
  case "$1" in
    amd64) echo "linux_amd64 linux/amd64 ubuntu-24.04" ;;
    386) echo "linux_386 linux/386 ubuntu-24.04" ;;
    arm64) echo "linux_arm64 linux/arm64 ubuntu-24.04-arm" ;;
    armv7) echo "linux_arm_v7 linux/arm/v7 ubuntu-24.04-arm" ;;
    *) return 1 ;;
  esac
}

archc_of() {
  local info
  info=$(arch_map "$1") || return 1
  echo "${info%% *}"
}
