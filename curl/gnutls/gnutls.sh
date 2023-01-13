#!/bin/sh

GNUTLS_VERSION="3.7.8"


# install root
INSTALL_DIR=${TOPDIR}/build




function get_gnutls_source() {
  VERSION=$1
  
  if [ ! -f gnutls-${VERSION}.tar.xz ] ; then
    BIG_VERSION=$(echo ${VERSION} | sed 's/\.[0-9]\+$//')
    wget https://www.gnupg.org/ftp/gcrypt/gnutls/${BIG_VERSION}/gnutls-${VERSION}.tar.xz
  fi
}



function build_gnutls_source() {
  VERSION=$1

  apk add nettle-dev nettle-static gmp-dev libunistring-dev libunistring-static 
  apk add libtasn1-dev p11-kit-dev

  if [ -d ${INSTALL_DIR} ] ; then
    rm -rf ${INSTALL_DIR}
  fi
  mkdir -p ${INSTALL_DIR}/data
  
  rm -rf gnutls-${VERSION}
  tar xf gnutls-${VERSION}.tar.xz
  cd     gnutls-${VERSION}

  ./configure \
      --build=x86_64-linux \
      --host=x86_64-linux \
      --prefix=${INSTALL_DIR} \
      --datadir=${INSTALL_DIR}/data \
      --enable-ktls \
      --disable-openssl-compatibility \
      --disable-rpath \
      --enable-static=yes \
      --enable-shared=no \
      --disable-guile \
      --disable-valgrind-tests

  make -j`nproc`
  make install
}

##########################################################################
if [ -z ${GNUTLS_VERSION} ] ; then
  GNUTLS_VERSION=$(get_gnutls_version)
fi

get_gnutls_source     ${GNUTLS_VERSION}

#verify_gnutls_source  ${GNUTLS_VERSION}

build_gnutls_source   ${GNUTLS_VERSION}