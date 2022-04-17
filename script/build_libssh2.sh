#!/bin/sh

set -e
# source the common build functions
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/common.sh"

function build_ssh2 () 
{
    ARCH="$1"
    title "Building for $ARCH"

    export CMAKE_PREFIX_PATH=$OPENSSL_DIR
    mkdir build && cd build
    cmake \
        -DBUILD_SHARED_LIBS=ON \
        -DENABLE_ZLIB_COMPRESSION=ON \
        -DCMAKE_OSX_ARCHITECTURES:STRING="${ARCH}" \
        -DCMAKE_INSTALL_PREFIX:STRING="$OUTPUT_DIR" \
        ..
    cmake --build . --target install
    cd -

    cd "$OUTPUT_DIR/lib"
    install_name_tool -id @rpath/libssh2.dylib libssh2.dylib
    mv "$(realpath libssh2.dylib)" libssh2.dylib.backup
    rm *.dylib
    mv libssh2.dylib.backup libssh2.dylib
    rm -rf cmake
    cd -
}

OUTPUT_DIR="$(pwd)/External/output"
OPENSSL_DIR="${OUTPUT_DIR}/openssl"
OUTPUT_DIR="${OUTPUT_DIR}/libssh2"

cd External
clone_cd git@github.com:libssh2/libssh2.git libssh2-1.10.0 libssh2

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

cleanup
build_ssh2 arm64
save_arch arm64

cleanup
build_ssh2 x86_64
save_arch x86_64

fat_binary arm64 x86_64

rm -rf "$OUTPUT_DIR/share"

echo "libssh2 has been updated."
