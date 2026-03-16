#!/usr/bin/env bash

set -e
set -x

export ARCH=arm64
export SUBARCH=arm64

WORKDIR=$(pwd)

echo "===== CLONE KERNEL SOURCE ====="
git clone --depth=1 https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b peridot-u-oss kernel

echo "===== CLONE CLANG TOOLCHAIN ====="
git clone --depth=1 https://github.com/kdrag0n/proton-clang clang

export PATH="$WORKDIR/clang/bin:$PATH"

echo "===== CLONE ANYKERNEL ====="
git clone --depth=1 https://github.com/osm0sis/AnyKernel3 AnyKernel

cd kernel

echo "===== INJECT KERNELSU NEXT ====="
git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next ksu
bash ksu/kernel/setup.sh

echo "===== FIX XIAOMI SOURCE BUG ====="

# hwid missing
sed -i '/hwid\/Kconfig/d' drivers/misc/Kconfig || true
sed -i '/hwid/d' drivers/misc/Makefile || true

echo "===== BUILD DEFCONFIG ====="
make O=out ARCH=arm64 vendor/pineapple_defconfig

echo "===== ENABLE FEATURES ====="

scripts/config --file out/.config \
-e KVM \
-e KVM_ARM_HOST \
-e KVM_ARM_VGIC \
-e KVM_ARM_TIMER \
-e VIRTUALIZATION \
-e VHOST_NET \
-e VSOCKETS \
-e VIRTIO \
-e OVERLAY_FS \
-e TMPFS_XATTR \
-e ANDROID_BINDERFS \
-e WIREGUARD \
-e BPF

echo "===== BUILD KERNEL ====="

make -j$(nproc --all) O=out \
ARCH=arm64 \
CC=clang \
LLVM=1 \
LLVM_IAS=1 \
HOSTCC=gcc \
HOSTCXX=g++

echo "===== COPY KERNEL ====="

cd ..

if [ -f kernel/out/arch/arm64/boot/Image.gz-dtb ]; then
    cp kernel/out/arch/arm64/boot/Image.gz-dtb AnyKernel/
elif [ -f kernel/out/arch/arm64/boot/Image.gz ]; then
    cp kernel/out/arch/arm64/boot/Image.gz AnyKernel/
elif [ -f kernel/out/arch/arm64/boot/Image ]; then
    cp kernel/out/arch/arm64/boot/Image AnyKernel/
else
    echo "Kernel image not found!"
    exit 1
fi

cd AnyKernel

echo "===== BUILD FLASHABLE ZIP ====="

zip -r PocoF6-Kernel-KSU-AVF.zip *

echo "===== BUILD DONE ====="
