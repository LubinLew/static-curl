#!/usr/bin/bash
set -e
cd `dirname $0`
#####################################
WORKDIR="/curl"
IMAGE="alpine:3.17"

# get latest version
function get_curl_version() {
  KEYWORD="Location: https://github.com/curl/curl/releases/tag/curl-"
  VERSION=$(curl -Isk 'https://github.com/curl/curl/releases/latest' | grep -i "${KEYWORD}" | sed "s#${KEYWORD}##i" | sed 's#_#.#g' | tr -d '\r')
  echo ${VERSION}
}

CURL_VERSION=$(get_curl_version)
LOCAL_VERSION=$(cat version.txt)

echo "== curl version: ${LOCAL_VERSION}/${CURL_VERSION}"
if [ "${CURL_VERSION}" == "${LOCAL_VERSION}" ] ; then
  echo "up to date"
  exit 0
fi

echo ${CURL_VERSION} > version.txt

#  '-e CURL_VERSION=7.87.0 -e TLS=wolfssl -e WOLFSSL_VERSION=5.5.4-stable'
#  '-e CURL_VERSION=7.87.0 -e TLS=bearssl'
#  '-e TLS=mbedtls'
#  '-e TLS=wolfssl'

DOCKERENVS=(
  '-e TLS=openssl'
  '-e TLS=wolfssl'
  '-e TLS=mbedtls'
  '-e TLS=bearssl'
)

docker pull ${IMAGE}

for RUNENV in "${DOCKERENVS[@]}" ; do
  LOGFILE_NAME=build_curl$(echo "${RUNENV}" | sed 's#-e#\n#g'|awk -F'=' '{print $2}'|paste -d '_' -s | tr -d ' ').log
  docker run --rm ${RUNENV} -v `pwd`/curl:${WORKDIR} -w ${WORKDIR} ${IMAGE} ${WORKDIR}/curl.sh 2>&1 | tee -a ${LOGFILE_NAME}
  cat curl/curl-${CURL_VERSION}/config.log >> ${LOGFILE_NAME}
done

