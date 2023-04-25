#!/bin/sh

set -e
# source the common build functions
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/common.sh"

function build() 
{
    ARCH=$1
    title "Building $1 binary..."

    mkdir build && cd build
    cmake -DUSE_SHARED_MBEDTLS_LIBRARY=On -DCMAKE_OSX_ARCHITECTURES:STRING="${ARCH}" ..
    cmake --build .
    cd -

    mkdir -p "${OUTPUT_DIR}/lib/"
    cd "build/library"

    install_name_tool -id @rpath/libmbedcrypto.dylib libmbedcrypto.dylib
    cp -L libmbedcrypto.dylib "${OUTPUT_DIR}/lib/"

    install_name_tool -id @rpath/libmbedtls.dylib libmbedtls.dylib
    install_name_tool -change @rpath/libmbedx509.5.dylib @rpath/libmbedx509.dylib libmbedtls.dylib 
    install_name_tool -change @rpath/libmbedcrypto.14.dylib @rpath/libmbedcrypto.dylib libmbedtls.dylib 
    cp -L libmbedtls.dylib "${OUTPUT_DIR}/lib/"

    install_name_tool -id @rpath/libmbedx509.dylib libmbedx509.dylib
    install_name_tool -change @rpath/libmbedcrypto.14.dylib @rpath/libmbedcrypto.dylib libmbedx509.dylib 
    cp -L libmbedx509.dylib "${OUTPUT_DIR}/lib/"

    cd -
}


OUTPUT_DIR=$(pwd)/External/output/mbedtls

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd External
clone_cd git@github.com:Mbed-TLS/mbedtls.git development mbedtls

title "Install Python Dependencies"
python3 -m pip install -r scripts/basic.requirements.txt

cleanup
build arm64
save_arch arm64

cleanup
build x86_64
save_arch x86_64

fat_binary arm64 x86_64

echo "Building done."
