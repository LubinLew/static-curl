#!/bin/sh
set -e
cd $(dirname $0)
############################################################
# [v]openssl, default
# [v]wolfssl, compile source code
# [v]bearssl, WARNING: not support TLSv1.3
# [v]mbedtls, WARNING: not support TLSv1.3
# [x]gnutls, there is no static library in apline(apk add gnutls-dev)
# [x]nss, there is no static library in apline(apk add nss nss-dev)
# [x]rustls, there is no packages in apline
# [x]schannel, there is no packages in apline
# [x]secure-transport, there is no packages in apline
# [x]amissl, there is no packages in apline
if [ -z ${TLS} ] ; then
  TLS="openssl"
fi

# http2
if [ -z ${HTTP2_SUPPORT} ] ; then
  HTTP2_SUPPORT="yes"
fi

# scp/sftp support
if [ -z ${SSH_SUPPORT} ] ; then
  SSH_SUPPORT="no"
fi

# IDN
if [ -z ${IDN_SUPPORT} ] ; then
  IDN_SUPPORT="yes"
fi

TLS_TEST_URL="https://www.ssllabs.com/favicon.ico"

## log
TAG="CURL"
############################################################

# get latest version
function get_curl_version() {
  apk add curl > /dev/null
  KEYWORD="Location: https://github.com/curl/curl/releases/tag/curl-"
  VERSION=$(curl -Isk 'https://github.com/curl/curl/releases/latest' | grep -i "${KEYWORD}" | sed "s#${KEYWORD}##i" | sed 's#_#.#g' | tr -d '\r')
  echo ${VERSION}
}

# gpg verify
function verify_curl_source() {
  VERSION=$1
  apk add gnupg gpg-agent > /dev/null

  echo "[${TAG}] downloading gpg public key ..."
  GPGKEY="https://daniel.haxx.se/mykey.asc"
  if [ ! -f mykey.asc ] ; then
    wget ${GPGKEY}
  fi

  echo "[${TAG}] verifying source ..."
  gpg --show-keys mykey.asc|grep '^ '|tr -d ' '|awk '{print $0":6:"}' > /tmp/ownertrust.txt
  gpg --import-ownertrust < /tmp/ownertrust.txt > /dev/null
  gpg --import mykey.asc  > /dev/null
  gpg --verify curl-${VERSION}.tar.bz2.asc curl-${VERSION}.tar.bz2
}

## download source
function get_curl_source() {
  VERSION=$1
  SOURCE="https://curl.se/download/curl-${VERSION}.tar.bz2"
  
  echo "[${TAG}] downloading source ..."
  if [ ! -f curl-${VERSION}.tar.bz2 ] ; then
    wget ${SOURCE}
  fi

  echo "[${TAG}] downloading signature file ..."
  if [ ! -f curl-${VERSION}.tar.bz2.asc ] ; then
    wget ${SOURCE}.asc
  fi
}

## build static
function build_curl_source() {
  VERSION=$1
  echo "[${TAG}] preparing for build ..."
  # install compiler
  apk add build-base clang > /dev/null

  apk add zlib-static  > /dev/null
  
  apk add util-linux-misc perl > /dev/null

  # apk add libpsl-static libpsl-dev > /dev/null

  if [ "${IDN_SUPPORT}" == "yes" ] ; then
    apk add libidn2-dev libidn2-static
    EXTRA_OPT="${EXTRA_OPT} --with-libidn2"
  fi

  # http2 support
  if [ "${HTTP2_SUPPORT}" == "yes" ] ; then
    apk add nghttp2-dev nghttp2-static > /dev/null
  fi

  # ssh suport(scp sftp)
  if [ "${SSH_SUPPORT}" == "yes" ] ; then
    apk add libssh2-dev libssh2-static > /dev/null
  fi

  # TLS support
  if [ "${TLS}" == "openssl" ] ; then
    apk add openssl-dev openssl-libs-static > /dev/null
  elif [ "${TLS}" == "bearssl" ] ; then
    apk add bearssl-dev > /dev/null
  elif [ "${TLS}" == "mbedtls" ] ; then
    apk add mbedtls-dev mbedtls-static > /dev/null
  else
    /bin/sh ${TLS}/${TLS}.sh
    TLS_OPT="=`pwd`/${TLS}/build"
  fi

  echo "[${TAG}] building source ..."
  rm -rf curl-${VERSION}
  tar xf curl-${VERSION}.tar.bz2
  ## pushd curl-${VERSION}
  cd     curl-${VERSION}

  export CC="clang"
  export ARCH="amd64"
  export LDFLAGS="-static -all-static"
  export PKG_CONFIG="pkg-config --static"

  ./configure --disable-shared --enable-static --enable-ipv6 \
       --enable-unix-sockets \
       --enable-tls-srp \
       --with-${TLS}${TLS_OPT} \
       --with-zlib \
       --disable-ldap \
       --disable-dict \
       --disable-gopher \
       --disable-imap \
       --disable-smtp \
       --disable-rtsp \
       --disable-telnet \
       --disable-tftp \
       --disable-pop3 \
       --disable-mqtt \
       --disable-ftp \
       --disable-smb \
       --without-libpsl \
       ${EXTRA_OPT}
  
  make -j`nproc`

  chmod +x src/curl
  /bin/cp -f src/curl ../curl_${VERSION}_${TLS}_${ARCH}
  /bin/cp -f src/curl ../curl_${VERSION}_${TLS}_${ARCH}.nonstrip
  strip -s ../curl_${VERSION}_${TLS}_${ARCH}

  src/curl -V
  ls -lh ../curl_${VERSION}_${TLS}_${ARCH}*

  ## popd
  cd ..
}


function test_curl_binary() {
  CURL="curl_$1_${TLS}_${ARCH}"
  echo "###### [$1][${TLS}][${ARCH}] ######"
  ./${CURL} -V

  if [ "${TLS}" == "bearssl" ] ; then
    TLSVER=$(apk list|grep bearssl-dev|awk -F'-' '{printf $3}')
  else
    TLSVER=$(./${CURL} -V | head -n 1 | sed 's/ /\n/g' | grep '/' | grep -i "${TLS}" | awk -F'/' '{print $2}')
  fi

  TLS13=$(./${CURL} -k --tlsv1.3 ${TLS_TEST_URL} -so /dev/null -w '%{http_code}' || true)
  TLS12=$(./${CURL} -k --tlsv1.2 ${TLS_TEST_URL} -so /dev/null -w '%{http_code}' || true)
  TLS11=$(./${CURL} -k --tlsv1.1 ${TLS_TEST_URL} -so /dev/null -w '%{http_code}' || true)
  TLS10=$(./${CURL} -k --tlsv1.0 ${TLS_TEST_URL} -so /dev/null -w '%{http_code}' || true)
  if [ "${TLS13}" == "200" ] ; then
    TLS13=":heavy_check_mark:"
  else
    TLS13=":x:"
  fi

  if [ "${TLS12}" == "200" ] ; then
    TLS12=":heavy_check_mark:"
  else
    TLS12=":x:"
  fi
  
  if [ "${TLS11}" == "200" ] ; then
    TLS11=":heavy_check_mark:"
  else
    TLS11=":x:"
  fi

  if [ "${TLS10}" == "200" ] ; then
    TLS10=":heavy_check_mark:"
  else
    TLS10=":x:"
  fi

  SUM1=$(sha256sum ${CURL}          | awk '{print $1}')
  SUM2=$(sha256sum ${CURL}.nonstrip | awk '{print $1}')

cat >> release.md<<EOF
| ${CURL}          | ${ARCH} | ${TLS}(${TLSVER}) | ${TLS10} | ${TLS11} | ${TLS12} | ${TLS13} | ${SUM1} |
| ${CURL}.nonstrip | ${ARCH} | ${TLS}(${TLSVER}) | ${TLS10} | ${TLS11} | ${TLS12} | ${TLS13} | ${SUM2} |
EOF
}

############################################################

if [ -z ${CURL_VERSION} ] ; then
  CURL_VERSION=$(get_curl_version)
fi
echo "[${TAG}] version=${CURL_VERSION}"

# create relese note file
if [ ! -f release.md ] ; then
cat > release.md<<EOF
# static curl ${CURL_VERSION}

| Name | Arch | TLS Provider | TLSv1.0 | TLSv1.1 | TLSv1.2 | TLSv1.3 | sha256sum |
|------|------|--------------|---------|---------|---------|---------|-----------|
EOF
chmod 777 release.md
fi

get_curl_source    ${CURL_VERSION}

verify_curl_source ${CURL_VERSION}

build_curl_source  ${CURL_VERSION}

test_curl_binary   ${CURL_VERSION}



