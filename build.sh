#!/bin/bash
# Original script by TIMISONG-dev
# Make sure you have zstd installed.

export DEVICE="munch"

start_time=$(date +%s)

MAINPATH=/home/olzhas0986

KERNEL_DIR=$MAINPATH
KERNEL_PATH=$KERNEL_DIR/kernel

CLANG_DIR=$KERNEL_DIR/clang24

check_and_wget() {
    local dir=$1
    local repo=$2

    if [ ! -d "$dir" ]; then
        echo "Directory $dir doesnt exist. Cloning $repo."
        mkdir $dir
        cd $dir
        wget $repo
        tar --zstd -xvf neutron-clang-06092026.tar.zst
        rm -rf neutron-clang-06092026.tar.zst
        cd ../kernel
    fi
}

check_and_wget $CLANG_DIR https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/06092026/neutron-clang-06092026.tar.zst

PATH=$CLANG_DIR/bin:$PATH
export PATH
export ARCH=arm64

PERF_DIR="$KERNEL_DIR/perf"

if [ ! -d "$PERF_DIR" ]; then
    mkdir -p "$PERF_DIR"
    
    if [ ! -d "$PERF_DIR/Anykernel" ]; then
        git clone https://github.com/olzhas0986/Anykernel3.git "$PERF_DIR/Anykernel"
        
        mv "$PERF_DIR/Anykernel/"* "$PERF_DIR/"
        
        rm -rf "$PERF_DIR/Anykernel"
    fi
else
    if [ -d "$PERF_DIR/.git" ]; then
        rm -rf "$PERF_DIR/.git"
    fi
fi

export IMGPATH="$PERF_DIR/Image"
export DTBPATH="$PERF_DIR/dtb"
export DTBOPATH="$PERF_DIR/dtbo.img"
export KBUILD_BUILD_USER="olzhas"
export KBUILD_BUILD_HOST="debian"

PERF_BUILD_DATE=$(date '+%Y-%m-%d_%H-%M-%S')

output_dir=out

make O="$output_dir" \
            vendor/${DEVICE}_defconfig

    make -j $(nproc) \
                O="$output_dir" \
                CC="ccache clang" \
                HOSTCC=gcc \
                LD=ld.lld \
                AS=llvm-as \
                AR=llvm-ar \
                NM=llvm-nm \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip \
                LLVM=1 \
                LLVM_IAS=1 \
                V=$VERBOSE 2>&1 | tee build.log
                

find $DTS -name '*.dtb' -exec cat {} + > $DTBPATH
find $DTS -name 'Image' -exec cat {} + > $IMGPATH
find $DTS -name 'dtbo.img' -exec cat {} + > $DTBOPATH

end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

cd "$KERNEL_PATH"

if grep -q -E "Error 2" build.log; then
    cd "$KERNEL_PATH"
    echo "Error: Compilation failed"
else
    echo "Total execution time: $elapsed_time second"
    cd "$PERF_DIR"
    7z a -mx9 LineageOS-perf-$DEVICE-$PERF_BUILD_DATE.zip * -x!*.zip
fi
