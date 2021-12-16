#!/bin/sh

set -ex
SCRIPT_DIR=$(realpath "$(dirname "$0")")
source "${SCRIPT_DIR}/common.sh"


# augment path to help it find cmake installed in /usr/local/bin,
# e.g. via brew. Xcode's Run Script phase doesn't seem to honor
# ~/.MacOSX/environment.plist
OUTPUT_DIR="$(pwd)/External/output"
OPENSSL_DIR="${OUTPUT_DIR}/openssl"
LIBSSH2_DIR="${OUTPUT_DIR}/libssh2"
LIBGIT2_DIR="${OUTPUT_DIR}/libgit2"
LIBGIT2_NAME="libgit2.dylib"

export PKG_CONFIG_PATH="$LIBSSH2_DIR/lib/pkgconfig:$OPENSSL_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
export PKG_CONFIG_LIBSSH2_PREFIX="$LIBSSH2_DIR"
export PKG_CONFIG_OPENSSL_PREFIX="$OPENSSL_DIR"
export PKG_CONFIG_LIBSSL_PREFIX="$OPENSSL_DIR"
export PKG_CONFIG_LIBCRYPTO_PREFIX="$OPENSSL_DIR"
export PATH="${LIBSSH2_DIR}/lib:${PATH}"


cd "External/libgit2"
git reset HEAD --hard

# Apply Patch
git apply "${SCRIPT_DIR}/libgit2_patch.diff"

# Copy Headers
rsync -av --delete --exclude=sys --exclude=.DS_Store include/ "${LIBGIT2_DIR}/git2.framework/Headers/"

function build_git2() {
    ARCH=$1
    cmake -DBUILD_SHARED_LIBS:BOOL=ON \
        -DBUILD_CLAR:BOOL=OFF \
        -DTHREADSAFE:BOOL=ON \
        -DUSE_GSSAPI:BOOL=ON \
        -DCMAKE_OSX_ARCHITECTURES:STRING="${ARCH}" \
        ..
    cmake --build .
}

function save_binary() {
    ARCH=$1
    local dir="${LIBGIT2_DIR}/${ARCH}"
    rm -rf "$dir"
    mkdir -p "$dir"
    cp -L "${LIBGIT2_NAME}" "$dir/"
}

function fat_binary() {
    echo "Building fat binary..."

    dir1="$1"
    dir2="$2"
    lipo -create "${dir1}/${LIBGIT2_NAME}" "${dir2}/${LIBGIT2_NAME}" -output "$LIBGIT2_NAME"
    rm -rf "$dir1"
    rm -rf "$dir2"
}

# Clean Build
rm -rf "build"
mkdir build
cd build

build_git2 "x86_64"
save_binary "x86_64"

cd ..

# Clean Build
rm -rf "build"
mkdir build
cd build

build_git2 arm64
save_binary arm64

# Merge Fat Binary
cd "${LIBGIT2_DIR}"
fat_binary x86_64 arm64

rsync --remove-source-files -av --copy-links "${LIBGIT2_NAME}" "git2.framework/git2"

# Change Install Name
cd "git2.framework"
install_name_tool -id @rpath/git2.framework/git2 git2

echo "git2.framework has been updated."
