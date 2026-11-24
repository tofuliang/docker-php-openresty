#!/usr/bin/env bash
#
# 自动更新指定 OpenResty 分支目录 Dockerfile 中的 RESTY_VERSION。
# 用法：
#   .github/scripts/update-openresty.sh openresty131
#
# 数据源：
#   https://openresty.org/en/download.html
#   https://openresty.org/download/openresty-<version>.tar.gz
set -uo pipefail

SED=$(command -v gsed || command -v sed)
OPENRESTY_DOWNLOAD_PAGE="https://openresty.org/en/download.html"
OPENRESTY_DIST_BASE="https://openresty.org/download"

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required" >&2; exit 1; }

# verComp A B  -> 0: equal, 1: A > B, 2: A < B
verComp() {
  if [[ $1 == $2 ]]; then
    return 0
  fi
  local IFS=.
  local i ver1=($1) ver2=($2)
  for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i = 0; i < ${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]:-} ]]; then
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 2
    fi
  done
  return 0
}

BRANCH_NAME=${1:-openresty131}
if [[ ! $BRANCH_NAME =~ ^openresty([0-9])([0-9]+)$ ]]; then
  echo "ERROR: unsupported branch name '$BRANCH_NAME' (expected e.g. openresty131)" >&2
  exit 1
fi
SERIES="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
SERIES_RE="${BASH_REMATCH[1]}\\.${BASH_REMATCH[2]}"

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DOCKERFILE="$ROOT/$BRANCH_NAME/Dockerfile"
[ -f "$DOCKERFILE" ] || { echo "ERROR: Dockerfile not found at $DOCKERFILE" >&2; exit 1; }

LOCAL_VER=$(grep -E '^ARG RESTY_VERSION="[^"]+"' "$DOCKERFILE" | head -1 |
  $SED -E 's/^ARG RESTY_VERSION="([^"]+)"$/\1/')

if [ -z "$LOCAL_VER" ]; then
  echo "ERROR: could not detect RESTY_VERSION in $DOCKERFILE" >&2
  exit 1
fi

HTML=$(curl -fsSL --retry 3 "${OPENRESTY_DOWNLOAD_PAGE}?t=$(date +%s)") || {
  echo "ERROR: failed to fetch ${OPENRESTY_DOWNLOAD_PAGE}" >&2
  exit 1
}

REMOTE_VER=$(echo "$HTML" |
  grep -Eo "openresty-${SERIES_RE}\.[0-9]+\.[0-9]+\.tar\.gz" |
  $SED -E 's/^openresty-//; s/\.tar\.gz$//' |
  sort -u -t. -k1,1nr -k2,2nr -k3,3nr -k4,4nr |
  head -1)

if ! [[ $REMOTE_VER =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: failed to resolve latest OpenResty ${SERIES}.x version" >&2
  exit 1
fi

echo "OpenResty version of $BRANCH_NAME/Dockerfile is $LOCAL_VER"
echo "latest OpenResty ${SERIES}.x version is $REMOTE_VER"

verComp "$LOCAL_VER" "$REMOTE_VER"
CMP=$?
if [ $CMP -ne 2 ]; then
  echo "$BRANCH_NAME ($LOCAL_VER) is up to date"
  exit 0
fi

TARBALL_URL="${OPENRESTY_DIST_BASE}/openresty-${REMOTE_VER}.tar.gz"
if ! curl -fsSLI --retry 3 "$TARBALL_URL" >/dev/null; then
  echo "ERROR: tarball not reachable: $TARBALL_URL" >&2
  exit 1
fi

echo "update $BRANCH_NAME to $REMOTE_VER ..."
$SED -Ei "s#^ARG RESTY_VERSION=.*#ARG RESTY_VERSION=\"${REMOTE_VER}\"#" "$DOCKERFILE"

UPDATED_VER=$(grep -E '^ARG RESTY_VERSION="[^"]+"' "$DOCKERFILE" | head -1 |
  $SED -E 's/^ARG RESTY_VERSION="([^"]+)"$/\1/')
if [ "$UPDATED_VER" != "$REMOTE_VER" ]; then
  echo "ERROR: failed to update RESTY_VERSION in $DOCKERFILE" >&2
  exit 1
fi
