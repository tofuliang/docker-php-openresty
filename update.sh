#!/usr/bin/env bash

function verComp() {
  if [[ $1 == $2 ]]; then
    return 0
  fi
  local IFS=.
  local i ver1=($1) ver2=($2)
  # fill empty fields in ver1 with zeros
  for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i = 0; i < ${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      # fill empty fields in ver2 with zeros
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

SED=`which gsed||which sed`

LOCAL_PHP_VER=$(cat Dockerfile | grep -vE '^\s*#'| grep -Eo "PHP_URL.{0,99}php-([0-9]+\.){3}" | grep -Eo "([0-9]+\.[0-9]+\.[0-9]+)")
REMOTE_PHP_INFO=`curl -ks https://www.php.net/downloads.php |tr -d "\n" `
#REMOTE_PHP_INFO=$(cat curl.log)

#echo $REMOTE_PHP_INFO
BRANCH=$(echo $1|$SED -E "s/([0-9])([0-9])/\1.\2/g")

SHA256=$(echo $REMOTE_PHP_INFO | grep -Eo "php-${BRANCH}\.[0-9]+\.tar\.xz.*?sha256\">\w{64}<" | grep -Eo "\w{64}"|head -1)

REMOTE_PHP_VER=$(echo $REMOTE_PHP_INFO | grep -Eo "php-${BRANCH}\.[0-9]+\.tar\.xz.asc" | grep -Eo "([0-9]+\.[0-9]+\.[0-9]+)")

echo ""
echo "PHP version of Dockerfile is $LOCAL_PHP_VER"

echo ""
echo "latest PHP version of $BRANCH is $REMOTE_PHP_VER"

echo ""
echo "sha256 of $REMOTE_PHP_VER.tar.xz is $SHA256"

verComp $LOCAL_PHP_VER $REMOTE_PHP_VER

if [ $? -eq 2 ]; then
  echo ""
  echo "update PHP to $REMOTE_PHP_VER ..."
  $SED -Ei "s/php-${BRANCH}\.[0-9]{1,3}.tar.xz/php-${REMOTE_PHP_VER}.tar.xz/g" Dockerfile
  $SED -Ei "s/\w{64}/$SHA256/g" Dockerfile
fi


LOCAL_SWOOLE_VER=$(cat Dockerfile | grep -vE '^\s*#'|grep -Eo " download swoole-([0-9]{1,3}\.?){3}"|grep -Eo "([0-9]{1,3}\.?){3}")
if [ "$LOCAL_SWOOLE_VER" = "4.8.11" ];then
  exit 0
fi
REMOTE_SWOOLE_INFO=`curl -ks https://pecl.php.net/package/swoole |tr -d "\n" `
#REMOTE_SWOOLE_INFO=$(cat swoole.log)

REMOTE_SWOOLE_VER=$(echo $REMOTE_SWOOLE_INFO | grep -Eo "get/swoole-([0-9]{1,3}\.?){3}.tgz" | grep -Eo "([0-9]+\.[0-9]+\.[0-9]+)" | head -1)

echo ""
echo "Swoole version of Dockerfile is $LOCAL_SWOOLE_VER"

echo ""
echo "latest Swoole version is $REMOTE_SWOOLE_VER"


verComp $LOCAL_SWOOLE_VER $REMOTE_SWOOLE_VER

if [ $? -eq 2 ]; then
  echo ""
  echo "update Swoole to $REMOTE_SWOOLE_VER ..."
  $SED -Ei "s/swoole-([0-9]+\.[0-9]+\.[0-9]+)/swoole-$REMOTE_SWOOLE_VER/g" Dockerfile
fi

