#!/bin/sh
set -e
cd `dirname $0`
TOPDIR=`pwd -P`
# https://www.wolfssl.com/documentation/manuals/wolfssl/wolfSSL-Manual.pdf
##########################################################################
TAG="WOLFSSL"
# install root
INSTALL_DIR=${TOPDIR}/build

##########################################################################

function get_wolfssl_version() {
  apk add curl > /dev/null
  KEYWORD="Location: https://github.com/wolfSSL/wolfssl/releases/tag/v"
  VERSION=$(curl -Isk 'https://github.com/wolfSSL/wolfssl/releases/latest/' | grep -i "${KEYWORD}" | sed "s#${KEYWORD}##i" | tr -d '\r')
  echo ${VERSION}
}

function verify_wolfssl_source() {
  VERSION=$1
  
  echo "[${TAG}] downloading gpg public key ..."
  GPGKEY="https://keys.openpgp.org/vks/v1/by-fingerprint/A2A48E7BCB96C5BECB987314EBC80E415CA29677"
  if [ ! -f wolfssl.asc ] ; then
     wget ${GPGKEY} -O wolfssl.asc
  fi

  echo "[${TAG}] verifying source ..."
  gpg --show-keys wolfssl.asc|grep '^ '|tr -d ' '|awk '{print $0":6:"}' > /tmp/ownertrust.txt
  gpg --import-ownertrust < /tmp/ownertrust.txt > /dev/null
  gpg --import wolfssl.asc  > /dev/null
  gpg --verify wolfssl-${VERSION}.tar.gz.asc wolfssl-${VERSION}.tar.gz
}

## download source
function get_wolfssl_source() {
  VERSION=$1

  echo "[${TAG}] downloading source ..."
  if [ ! -f wolfssl-${VERSION}.tar.gz ] ; then
    wget https://github.com/wolfSSL/wolfssl/archive/refs/tags/v${VERSION}.tar.gz -O wolfssl-${VERSION}.tar.gz
  fi

  echo "[${TAG}] downloading signature file ..."
  if [ ! -f wolfssl-${VERSION}.tar.gz.asc ] ; then
    wget https://github.com/wolfSSL/wolfssl/releases/download/v${VERSION}/wolfssl-${VERSION}.tar.gz.asc
  fi
}

## build static
function build_wolfssl_source() {
  VERSION=$1
  echo "[${TAG}] building source ..."
  apk add openssl-dev openssl-libs-static > /dev/null
  apk add autoconf automake libtool > /dev/null

  if [ -d ${INSTALL_DIR} ] ; then
    rm -rf ${INSTALL_DIR}
  fi
  mkdir -p ${INSTALL_DIR}/data

  rm -rf wolfssl-${VERSION}
  tar xf wolfssl-${VERSION}.tar.gz
  cd     wolfssl-${VERSION}

  ./autogen.sh

  ./configure \
    --build=x86_64-linux \
    --host=x86_64-linux \
    --prefix=${INSTALL_DIR} \
    --datadir=${INSTALL_DIR}/data \
    --localstatedir=/var \
    --enable-shared=no \
    --enable-static=yes \
    --enable-reproducible-build \
    --disable-opensslall \
    --enable-opensslextra \
    --disable-opensslcoexist \
    --enable-aescbc-length-checks \
    --enable-curve25519 \
    --enable-ed25519 \
    --enable-ed25519-stream \
    --disable-oldtls \
    --enable-base64encode \
    --enable-tlsx \
    --enable-scrypt \
    --disable-examples

  make -j`nproc`
  make install
}

##########################################################################
if [ -z ${WOLFSSL_VERSION} ] ; then
  WOLFSSL_VERSION=$(get_wolfssl_version)
fi
echo "[${TAG}] version=${WOLFSSL_VERSION}"

get_wolfssl_source     ${WOLFSSL_VERSION}

verify_wolfssl_source  ${WOLFSSL_VERSION}

build_wolfssl_source   ${WOLFSSL_VERSION}
