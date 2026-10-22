#!/usr/bin/env bash
#
# 自动更新当前目录 Dockerfile 中的 PHP / Swoole 版本。
# 用法（与 .github/workflows/update.yml 保持一致，在分支目录内执行）：
#   cd php83 && ../update.sh 83
#
# 数据源（php.net / pecl 的官方机器可读接口）：
#   PHP  : https://www.php.net/releases/index.php?json&version=8.3
#   PECL : https://pecl.php.net/rest/r/swoole/allreleases.xml
#          https://pecl.php.net/rest/r/swoole/package.<version>.xml
set -uo pipefail

SED=$(command -v gsed || command -v sed)

PHP_RELEASES_API="https://www.php.net/releases/index.php?json"
PHP_DIST_BASE="https://www.php.net/distributions"
SWOOLE_REST_API="https://pecl.php.net/rest/r/swoole"
GPG_KEYSERVER="keyserver.ubuntu.com"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required" >&2; exit 1; }
[ -f Dockerfile ] || { echo "ERROR: Dockerfile not found in $(pwd)" >&2; exit 1; }

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

BRANCH=$(echo "${1:?php branch number is required, e.g. 83}" | $SED -E "s/([0-9])([0-9])/\1.\2/g")

###############################################################################
# PHP
###############################################################################
LOCAL_PHP_VER=$(grep -vE '^[[:space:]]*#' Dockerfile |
  grep -Eo 'php-[0-9]+\.[0-9]+\.[0-9]+\.tar\.xz' | head -1 |
  $SED -E 's/^php-//; s/\.tar\.xz$//')

if [ -z "$LOCAL_PHP_VER" ]; then
  echo "ERROR: unable to detect the PHP version in Dockerfile" >&2
  exit 1
fi

RELEASE_JSON=$(curl -fsSL --retry 3 "$PHP_RELEASES_API&version=$BRANCH") || {
  echo "ERROR: unable to fetch PHP release metadata for $BRANCH" >&2
  exit 1
}

REMOTE_PHP_VER=$(jq -r '
  if type == "object" then
    if has("version") then .version
    else (to_entries | map(.value) | map(select(.version != null)) | first | .version) // empty
    end
  else empty end' <<<"$RELEASE_JSON")
SHA256=$(jq -r '
  if type == "object" and has("source") then
    ([.source[] | select(.filename | endswith(".tar.xz"))][0].sha256) // empty
  else empty end' <<<"$RELEASE_JSON")

if ! [[ $REMOTE_PHP_VER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || ! [[ $SHA256 =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: invalid PHP release metadata for $BRANCH (version='$REMOTE_PHP_VER')" >&2
  exit 1
fi

echo ""
echo "PHP version of Dockerfile is $LOCAL_PHP_VER"
echo ""
echo "latest PHP version of $BRANCH is $REMOTE_PHP_VER"
echo ""
echo "sha256 of $REMOTE_PHP_VER.tar.xz is $SHA256"

verComp "$LOCAL_PHP_VER" "$REMOTE_PHP_VER"
PHP_CMP=$?
if [ $PHP_CMP -eq 2 ]; then
  echo ""
  echo "update PHP to $REMOTE_PHP_VER ..."
  LOCAL_PHP_VER=$REMOTE_PHP_VER
elif [ $PHP_CMP -eq 1 ]; then
  echo ""
  echo "WARN: Dockerfile PHP ($LOCAL_PHP_VER) is newer than php.net ($REMOTE_PHP_VER), keep it" >&2
fi

# secure.php.net/get/.../from/this/mirror 镜像入口已下线（返回 404），
# 统一改成 https://www.php.net/distributions 直链。
$SED -Ei \
  -e "s#^ARG PHP_URL=.*#ARG PHP_URL=\"${PHP_DIST_BASE}/php-${LOCAL_PHP_VER}.tar.xz\"#" \
  -e "s#^ARG PHP_ASC_URL=.*#ARG PHP_ASC_URL=\"${PHP_DIST_BASE}/php-${LOCAL_PHP_VER}.tar.xz.asc\"#" \
  Dockerfile

if [ "$LOCAL_PHP_VER" != "$(grep -vE '^[[:space:]]*#' Dockerfile | grep -Eo 'php-[0-9]+\.[0-9]+\.[0-9]+\.tar\.xz' | head -1 | $SED -E 's/^php-//; s/\.tar\.xz$//')" ]; then
  echo "ERROR: failed to update the PHP version in Dockerfile" >&2
  exit 1
fi

# 只替换 PHP_SHA256 这一行，避免误伤 Dockerfile 里其它的 64 位十六进制串
if [ $PHP_CMP -ne 1 ]; then
  $SED -Ei "s#^ARG PHP_SHA256=.*#ARG PHP_SHA256=\"${SHA256}\"#" Dockerfile
fi

# 官方签名密钥每个发布分支/发布经理都会变，旧 key 会导致 gpg --verify 失败。
# 直接从新版 .asc 里读取实际签发者（subkey id），并写入 GPG_KEYS。
ASC_URL=$(grep -Eo '^ARG PHP_ASC_URL="[^"]+"' Dockerfile | head -1 |
  $SED -E 's/^ARG PHP_ASC_URL="(.*)"$/\1/')
if [ -n "$ASC_URL" ] && command -v gpg >/dev/null 2>&1; then
  NEW_KEY=$(curl -fsSL --retry 3 "$ASC_URL" | gpg --list-packets 2>/dev/null |
    $SED -nE 's/.*keyid ([0-9A-F]{16}).*/\1/p' | head -1)
  if [ -n "$NEW_KEY" ]; then
    CURRENT_KEYS=$(grep -Eo '^ARG GPG_KEYS="[^"]*"' Dockerfile | head -1 |
      $SED -E 's/^ARG GPG_KEYS="(.*)"$/\1/')
    if [ "$CURRENT_KEYS" != "$NEW_KEY" ]; then
      echo ""
      echo "update GPG key(s) to $NEW_KEY ..."
      $SED -Ei "s#^ARG GPG_KEYS=.*#ARG GPG_KEYS=\"${NEW_KEY}\"#" Dockerfile
    fi
  else
    echo "WARN: unable to read the signer of $ASC_URL, keep GPG_KEYS untouched" >&2
  fi
fi

# ha.pool.sks-keyservers.net 早已停止服务，换成 keyserver.ubuntu.com
$SED -Ei "s#--keyserver [^ ]+#--keyserver ${GPG_KEYSERVER}#g" Dockerfile

###############################################################################
# Swoole
###############################################################################
# Dockerfile 里可能同时存在多个版本（如 amd64/arm64 与 386 各一份），取最大值比较。
LOCAL_SWOOLE_VER=""
for v in $(grep -vE '^[[:space:]]*#' Dockerfile |
  grep -Eo 'swoole-[0-9]+\.[0-9]+\.[0-9]+' |
  $SED -E 's/^swoole-//' | sort -u); do
  if [ -z "$LOCAL_SWOOLE_VER" ]; then
    LOCAL_SWOOLE_VER=$v
  else
    verComp "$v" "$LOCAL_SWOOLE_VER"
    [ $? -eq 1 ] && LOCAL_SWOOLE_VER=$v
  fi
done

if [ -z "$LOCAL_SWOOLE_VER" ]; then
  echo ""
  echo "no swoole in Dockerfile, skip"
  exit 0
fi

ALL_RELEASES=$(curl -fsSL --retry 3 "$SWOOLE_REST_API/allreleases.xml") || {
  echo "ERROR: unable to fetch swoole releases" >&2
  exit 1
}

REMOTE_SWOOLE_VER=""
while read -r v; do
  [ -n "$v" ] || continue
  verComp "$v" "$LOCAL_SWOOLE_VER"
  [ $? -eq 1 ] || continue

  # Swoole 新版本对 PHP 有最低版本要求（例如 6.x 需要 PHP >= 8.1/8.2），
  # 必须挑“当前分支 PHP 能装上的最新版”，否则构建直接失败。
  PHP_MIN=$(curl -fsSL --retry 2 "$SWOOLE_REST_API/package.$v.xml" |
    tr -d '[:space:]' | grep -Eo '<php><min>[0-9.]+' | grep -Eo '[0-9.]+' | head -1)
  [ -n "$PHP_MIN" ] || continue
  verComp "$PHP_MIN" "$LOCAL_PHP_VER"
  # 该版本要求的最低 PHP 高于当前分支 -> 跳过
  [ $? -eq 1 ] && continue

  REMOTE_SWOOLE_VER=$v
  break
done <<<"$(echo "$ALL_RELEASES" |
  grep -Eo '<v>[0-9]+\.[0-9]+\.[0-9]+</v><s>stable</s>' |
  $SED -E 's#<v>([0-9.]+)</v><s>stable</s>#\1#' |
  sort -t. -k1,1nr -k2,2nr -k3,3nr)"

echo ""
echo "Swoole version of Dockerfile is $LOCAL_SWOOLE_VER"
echo ""
echo "latest Swoole version compatible with PHP $LOCAL_PHP_VER is ${REMOTE_SWOOLE_VER:-none}"

if [ -n "$REMOTE_SWOOLE_VER" ] && [ "$REMOTE_SWOOLE_VER" != "$LOCAL_SWOOLE_VER" ]; then
  echo ""
  echo "update Swoole to $REMOTE_SWOOLE_VER ..."
  $SED -Ei "s/swoole-[0-9]+\.[0-9]+\.[0-9]+/swoole-${REMOTE_SWOOLE_VER}/g" Dockerfile
fi
