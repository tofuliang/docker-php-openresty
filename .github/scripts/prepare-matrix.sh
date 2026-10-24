#!/usr/bin/env bash
#
# 根据派发参数生成构建矩阵。
# 输入：INPUT（空格/逗号分隔）或 PAYLOAD（JSON 数组，来自 repository_dispatch）。
# 输出：builders / images / modern / merge 四个 GITHUB_OUTPUT。
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CONFIG="$ROOT/.github/branches.json"
source "$ROOT/.github/scripts/arch.sh"

requested=()
if [ -n "${DEBUG_BRANCH:-}" ]; then
  requested=("$DEBUG_BRANCH")
elif [ -n "${INPUT:-}" ]; then
  read -r -a requested <<<"${INPUT//,/ }"
elif [ -n "${PAYLOAD:-}" ] && [ "${PAYLOAD}" != "null" ]; then
  # 兼容两种派发格式：JSON 数组，或 JSON 编码后的字符串
  if ! payload=$(jq -c 'if type == "string" then fromjson else . end' <<<"${PAYLOAD}" 2>/dev/null); then
    echo "::error::invalid repository_dispatch payload: ${PAYLOAD}"
    exit 1
  fi
  mapfile -t requested < <(jq -r '.[]' <<<"${payload}")
fi
explicit=0
if [ ${#requested[@]} -gt 0 ] && [ -z "${DEBUG_BRANCH:-}" ]; then explicit=1; fi
if [ ${#requested[@]} -eq 0 ]; then
  mapfile -t requested < <(jq -r 'keys[]' "$CONFIG")
fi

builders=()
modern=""
arch_branches=()
resolved=0
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
      php-builder | php-builder-modern)
        builders+=("$branch")
        resolved=$((resolved + 1))
        ;;
      php-modern)
        modern="true"
        resolved=$((resolved + 1))
        ;;
      *) echo "::warning::multi-mode branch '$branch' is not a known builder, skipped" ;;
    esac
    continue
  fi

  arch_branches+=("$branch")
  while IFS= read -r arch; do
    info=$(arch_map "$arch") || {
      echo "::error::unknown arch '${arch}' for '${branch}' (see .github/scripts/arch.sh)"
      exit 1
    }
    read -r archc platform runner <<<"$info"
    jq -cn \
      --arg branch "$branch" --arg arch "$arch" --arg archc "$archc" \
      --arg platform "$platform" --arg runner "$runner" \
      '{branch:$branch, arch:$arch, archc:$archc, platform:$platform, runner:$runner}' \
      >>"$arch_entries"
  done < <(jq -r --arg b "$branch" '.[$b].arches[]' "$CONFIG")
  resolved=$((resolved + 1))
done

if [ "$explicit" -gt 0 ] && [ "$resolved" -eq 0 ]; then
  echo "::error::none of the requested branches exist: ${requested[*]}"
  exit 1
fi

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
