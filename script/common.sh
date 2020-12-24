
export MACOSX_DEPLOYMENT_TARGET=10.15

function cleanup () 
{
    echo "Clean..."
    git clean -fdx
}

function save_arch() {
    target="${OUTPUT_DIR}/lib_$1"
    rm -rf "${target}"
    cp -a "${OUTPUT_DIR}/lib" "${target}"
}

function fat_binary() {
    echo "Building fat binary..."

    target="${OUTPUT_DIR}/lib"
	dir1="${OUTPUT_DIR}/lib_$1"
	dir2="${OUTPUT_DIR}/lib_$2"
    cd "${dir1}"
    for name in **.dylib; do
        rm -rf "${target}/$name"
        if [[ -L $name ]]; then
            cp -a "${dir1}/$name" "${target}/$name"
        else
            lipo -create "${dir1}/$name" "${dir2}/$name" -output "${target}/$name"
        fi
    done
    rm -rf "$dir1"
    rm -rf "$dir2"
}
