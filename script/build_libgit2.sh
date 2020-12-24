#!/bin/sh

set -e
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/common.sh"


# augment path to help it find cmake installed in /usr/local/bin,
# e.g. via brew. Xcode's Run Script phase doesn't seem to honor
# ~/.MacOSX/environment.plist
OUTPUT_DIR="$(pwd)/External/output"
OPENSSL_DIR="${OUTPUT_DIR}/openssl"
LIBSSH2_DIR="${OUTPUT_DIR}/libssh2"
LIBGIT2_DIR="${OUTPUT_DIR}/libgit2"

# export PKG_CONFIG_PATH="$LIBSSH2_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"

# libssh2 search path
export PATH="${LIBSSH2_DIR}/lib:${PATH}"

product="git2.framework/git2"

# if [ "${product}" -nt "External/libgit2" ]
# then
#     echo "No update needed."
#     exit 0
# fi

cd "External/libgit2"
rm -rf "build"
mkdir build
cd build

function build_git2() {
	ARCH=$1
	cmake -DBUILD_SHARED_LIBS:BOOL=ON \
	    -DLIBSSH2_INCLUDE_DIRS:PATH="${LIBSSH2_DIR}/include" \
	    -DBUILD_CLAR:BOOL=OFF \
	    -DTHREADSAFE:BOOL=ON \
	    -DUSE_GSSAPI:BOOL=ON \
        -DCMAKE_OSX_ARCHITECTURES:STRING="${ARCH}" \
        -DCMAKE_PREFIX_PATH:PATH="${OPENSSL_DIR}" \
	    ..
	cmake --build .
}

function save_binary() {
	ARCH=$1
	rm -rf "$ARCH"
	mkdir -p "$ARCH"
	cp -a *.dylib "$ARCH/"
}

function fat_binary() {
    echo "Building fat binary..."

	dir1="$1"
	dir2="$2"
    for name in *.dylib; do
        if ! [[ -L $name ]]; then
	        rm -rf "$name"
            lipo -create "${dir1}/$name" "${dir2}/$name" -output "$name"
        fi
    done
    rm -rf "$dir1"
    rm -rf "$dir2"
}

build_git2 "x86_64"
save_binary "x86_64"

build_git2 arm64
save_binary arm64

fat_binary x86_64 arm64

rsync -av --copy-links libgit2.dylib "${LIBGIT2_DIR}/git2.framework/git2"
cd "${LIBGIT2_DIR}/git2.framework"
install_name_tool -id @rpath/git2.framework/git2 git2

echo "git2.framework has been updated."
