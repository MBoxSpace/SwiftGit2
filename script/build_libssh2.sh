#!/bin/bash

set -e
# source the common build functions
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/common.sh"

function build_ssh2 () 
{
	ARCH="$1"
	export CFLAGS="-arch ${ARCH}"

	./buildconf
	./configure --enable-shared --disable-static\
		--host=${ARCH}-apple-darwin\
		--with-libssl-prefix="${OPENSSL_DIR}"\
		--prefix="${OUTPUT_DIR}"
	make
	make install

	cd "${OUTPUT_DIR}/lib"
    install_name_tool -id @rpath/libssh2.dylib libssh2.dylib
    rm -rf libssh2.dylib
    cp libssh2.1.dylib libssh2.dylib
    rm libssh2.1.dylib
    cd -
}

OUTPUT_DIR="$(pwd)/External/output"
OPENSSL_DIR="${OUTPUT_DIR}/openssl"
OUTPUT_DIR="${OUTPUT_DIR}/libssh2"

cd "External/libssh2"

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

cleanup
build_ssh2 arm64
save_arch arm64

cleanup
build_ssh2 x86_64
save_arch x86_64

fat_binary arm64 x86_64

echo "libssh2 has been updated."
