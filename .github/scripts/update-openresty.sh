#!/usr/bin/env bash
#
# 自动更新指定 OpenResty 分支目录 Dockerfile 中的 RESTY_VERSION 与 OpenSSL 版本。
# 用法：
#   .github/scripts/update-openresty.sh openresty131
#
# 数据源：
#   OpenResty: https://openresty.org/en/download.html
#              https://openresty.org/download/openresty-<version>.tar.gz
#   OpenSSL  : https://raw.githubusercontent.com/openresty/openresty-packaging/master/alpine/openresty-openssl3/APKBUILD
#              https://github.com/openssl/openssl/releases/download/openssl-<version>/openssl-<version>.tar.gz
set -uo pipefail

SED=$(command -v gsed || command -v sed)
OPENRESTY_DOWNLOAD_PAGE="https://openresty.org/en/download.html"
OPENRESTY_DIST_BASE="https://openresty.org/download"
OPENSSL_APKBUILD_URL="https://raw.githubusercontent.com/openresty/openresty-packaging/master/alpine/openresty-openssl3/APKBUILD"
OPENSSL_DIST_BASE="https://github.com/openssl/openssl/releases/download"
OPENRESTY_PATCH_BASE="https://raw.githubusercontent.com/openresty/openresty/master/patches"

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
if [ $CMP -eq 2 ]; then
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
else
  echo "$BRANCH_NAME ($LOCAL_VER) is up to date"
fi

###############################################################################
# OpenSSL
###############################################################################
LOCAL_OPENSSL_VER=$(grep -E '^ARG RESTY_OPENSSL_VERSION="[^"]+"' "$DOCKERFILE" | head -1 |
  $SED -E 's/^ARG RESTY_OPENSSL_VERSION="([^"]+)"$/\1/')
LOCAL_OPENSSL_PATCH_VER=$(grep -E '^ARG RESTY_OPENSSL_PATCH_VERSION="[^"]+"' "$DOCKERFILE" | head -1 |
  $SED -E 's/^ARG RESTY_OPENSSL_PATCH_VERSION="([^"]+)"$/\1/')

if [ -z "$LOCAL_OPENSSL_VER" ] || [ -z "$LOCAL_OPENSSL_PATCH_VER" ]; then
  echo "ERROR: could not detect RESTY_OPENSSL_VERSION or RESTY_OPENSSL_PATCH_VERSION in $DOCKERFILE" >&2
  exit 1
fi

APKBUILD=$(curl -fsSL --retry 3 "${OPENSSL_APKBUILD_URL}?t=$(date +%s)") || {
  echo "ERROR: failed to fetch ${OPENSSL_APKBUILD_URL}" >&2
  exit 1
}

REMOTE_OPENSSL_VER=$(echo "$APKBUILD" |
  grep -E '^pkgver="?[0-9]+\.[0-9]+\.[0-9]+"?' | head -1 |
  $SED -E 's/^pkgver="?([0-9]+\.[0-9]+\.[0-9]+)"?.*$/\1/')
REMOTE_OPENSSL_PATCH_VER=$(echo "$APKBUILD" |
  grep -Eo 'openssl-[0-9]+\.[0-9]+\.[0-9]+-sess_set_get_cb_yield\.patch' | head -1 |
  $SED -E 's/^openssl-([0-9]+\.[0-9]+\.[0-9]+)-sess_set_get_cb_yield\.patch$/\1/')

if ! [[ $REMOTE_OPENSSL_VER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || ! [[ $REMOTE_OPENSSL_PATCH_VER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: failed to resolve OpenSSL version/patch from APKBUILD" >&2
  exit 1
fi

echo "OpenSSL version of $BRANCH_NAME/Dockerfile is $LOCAL_OPENSSL_VER (patch $LOCAL_OPENSSL_PATCH_VER)"
echo "latest OpenSSL version in openresty-packaging is $REMOTE_OPENSSL_VER (patch $REMOTE_OPENSSL_PATCH_VER)"

verComp "$LOCAL_OPENSSL_VER" "$REMOTE_OPENSSL_VER"
OPENSSL_CMP=$?
if [ $OPENSSL_CMP -eq 2 ] || { [ $OPENSSL_CMP -eq 0 ] && [ "$LOCAL_OPENSSL_PATCH_VER" != "$REMOTE_OPENSSL_PATCH_VER" ]; }; then
  OPENSSL_TARBALL_URL="${OPENSSL_DIST_BASE}/openssl-${REMOTE_OPENSSL_VER}/openssl-${REMOTE_OPENSSL_VER}.tar.gz"
  if ! curl -fsSLI --retry 3 "$OPENSSL_TARBALL_URL" >/dev/null; then
    echo "ERROR: OpenSSL tarball not reachable: $OPENSSL_TARBALL_URL" >&2
    exit 1
  fi

  OPENSSL_PATCH_URL="${OPENRESTY_PATCH_BASE}/openssl-${REMOTE_OPENSSL_PATCH_VER}-sess_set_get_cb_yield.patch"
  if ! curl -fsSLI --retry 3 "$OPENSSL_PATCH_URL" >/dev/null; then
    echo "ERROR: OpenSSL patch not reachable: $OPENSSL_PATCH_URL" >&2
    exit 1
  fi

  echo "update $BRANCH_NAME OpenSSL to $REMOTE_OPENSSL_VER (patch $REMOTE_OPENSSL_PATCH_VER) ..."
  $SED -Ei \
    -e "s#^ARG RESTY_OPENSSL_VERSION=.*#ARG RESTY_OPENSSL_VERSION=\"${REMOTE_OPENSSL_VER}\"#" \
    -e "s#^ARG RESTY_OPENSSL_PATCH_VERSION=.*#ARG RESTY_OPENSSL_PATCH_VERSION=\"${REMOTE_OPENSSL_PATCH_VER}\"#" \
    "$DOCKERFILE"

  UPDATED_OPENSSL_VER=$(grep -E '^ARG RESTY_OPENSSL_VERSION="[^"]+"' "$DOCKERFILE" | head -1 |
    $SED -E 's/^ARG RESTY_OPENSSL_VERSION="([^"]+)"$/\1/')
  UPDATED_OPENSSL_PATCH_VER=$(grep -E '^ARG RESTY_OPENSSL_PATCH_VERSION="[^"]+"' "$DOCKERFILE" | head -1 |
    $SED -E 's/^ARG RESTY_OPENSSL_PATCH_VERSION="([^"]+)"$/\1/')
  if [ "$UPDATED_OPENSSL_VER" != "$REMOTE_OPENSSL_VER" ] || [ "$UPDATED_OPENSSL_PATCH_VER" != "$REMOTE_OPENSSL_PATCH_VER" ]; then
    echo "ERROR: failed to update OpenSSL version/patch in $DOCKERFILE" >&2
    exit 1
  fi
else
  echo "$BRANCH_NAME OpenSSL ($LOCAL_OPENSSL_VER) is up to date"
fi
