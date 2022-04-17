
export MACOSX_DEPLOYMENT_TARGET=10.15

function cleanup () 
{
    title "Clean..."
    git clean -fdx
}

function save_arch() {
    title "Save $1 arch..."
    target="${OUTPUT_DIR}/lib_$1"
    rm -rf "${target}"
    cp -a "${OUTPUT_DIR}/lib" "${target}"
}

function fat_binary() {
    title "Building fat binary..."

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

function title() {
    YELLOW='\033[0;33m'
    NC='\033[0m'
    echo "$YELLOW$@$NC"
}

function clone_cd() {
    url=$1
    ref=$2
    name=$3
    if ! [[ -d "$name" ]]; then
        title "Clone $name"
        git clone --no-checkout --filter="blob:none" $url "$name"
    fi
    cd "$name"
    git reset HEAD --hard
    git checkout -f "$ref"
}
