#!/bin/bash

set -e

# source the common build functions
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/common.sh"

function build_ssl () 
{
    echo "Building $1 binary..."

    MACHINE=$1 ./config --prefix="$OUTPUT_DIR"
    make
    make install

    cd "${OUTPUT_DIR}/lib"

    rm -rf libcrypto.dylib
    cp libcrypto.1.1.dylib libcrypto.dylib
    install_name_tool -id @rpath/libcrypto.dylib libcrypto.dylib
    rm -rf libcrypto.1.1.dylib

    rm -rf libssl.dylib
    cp libssl.1.1.dylib libssl.dylib
    install_name_tool -id @rpath/libssl.dylib libssl.dylib
    install_name_tool -change "${OUTPUT_DIR}/lib/libcrypto.1.1.dylib" @rpath/libcrypto.dylib libssl.dylib
    rm -rf libssl.1.1.dylib

    cd -
}


OUTPUT_DIR=$(pwd)/External/output/openssl
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd External
clone_cd git@github.com:openssl/openssl.git OpenSSL_1_1_1n openssl

cleanup
build_ssl arm64
save_arch arm64

cleanup
build_ssl x86_64
save_arch x86_64

fat_binary arm64 x86_64

echo "Building done."
