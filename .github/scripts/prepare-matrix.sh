#!/usr/bin/env bash
#
# 根据派发参数生成构建矩阵。
# 输入：INPUT（空格分隔）或 PAYLOAD（JSON 数组，来自 repository_dispatch）。
# 输出：builders / images / modern / merge 四个 GITHUB_OUTPUT。
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CONFIG="$ROOT/.github/branches.json"

requested=()
if [ -n "${INPUT:-}" ]; then
  read -r -a requested <<<"${INPUT}"
elif [ -n "${PAYLOAD:-}" ] && [ "${PAYLOAD}" != "null" ]; then
  # 兼容两种派发格式：JSON 数组，或 JSON 编码后的字符串
  payload=$(jq -c 'if type == "string" then fromjson else . end' <<<"${PAYLOAD}")
  mapfile -t requested < <(jq -r '.[]' <<<"${payload}")
fi
if [ ${#requested[@]} -eq 0 ]; then
  mapfile -t requested < <(jq -r 'keys[]' "$CONFIG")
fi

builders=()
modern=""
arch_branches=()
arch_entries="$(mktemp)"
trap 'rm -f "$arch_entries"' EXIT

for branch in "${requested[@]}"; do
  if ! jq -e --arg b "$branch" 'has($b)' "$CONFIG" >/dev/null; then
    echo "::warning::unknown branch '$branch', skipped"
    continue
  fi
  if [ ! -f "$ROOT/$branch/Dockerfile" ]; then
    echo "::warning::no Dockerfile for branch '$branch', skipped"
    continue
  fi

  mode=$(jq -r --arg b "$branch" '.[$b].mode // "single"' "$CONFIG")
  if [ "$mode" = "multi" ]; then
    case "$branch" in
      php-builder | php-builder-modern) builders+=("$branch") ;;
      php-modern) modern="true" ;;
      *) echo "::warning::multi-mode branch '$branch' is not a known builder, skipped" ;;
    esac
    continue
  fi

  arch_branches+=("$branch")
  while IFS= read -r arch; do
    case "$arch" in
      amd64) archc=linux_amd64; platform=linux/amd64; runner=ubuntu-26.04 ;;
      386)   archc=linux_386;   platform=linux/386;   runner=ubuntu-26.04 ;;
      arm64) archc=linux_arm64; platform=linux/arm64; runner=ubuntu-26.04-arm ;;
      armv7) archc=linux_arm_v7; platform=linux/arm/v7; runner=ubuntu-26.04-arm ;;
      *) echo "::error::unknown arch '$arch' for '$branch'"; exit 1 ;;
    esac
    jq -cn \
      --arg branch "$branch" --arg arch "$arch" --arg archc "$archc" \
      --arg platform "$platform" --arg runner "$runner" \
      '{branch:$branch, arch:$arch, archc:$archc, platform:$platform, runner:$runner}' \
      >>"$arch_entries"
  done < <(jq -r --arg b "$branch" '.[$b].arches[]' "$CONFIG")
done

builders_json=$(printf '%s\n' "${builders[@]+"${builders[@]}"}" | jq -R . | jq -sc '[.[] | select(length > 0)]')
images_json=$(jq -sc '.' "$arch_entries")
merge_json=$(printf '%s\n' "${arch_branches[@]+"${arch_branches[@]}"}" | jq -R . | jq -sc '[.[] | select(length > 0)]')

emit() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1=$2" >>"$GITHUB_OUTPUT"
  else
    echo "$1=$2"
  fi
}

emit builders "$builders_json"
emit images "$images_json"
emit modern "$modern"
emit merge "$merge_json"
