#!/usr/bin/env bash

set -e
set -x

export ARCH=arm64
export SUBARCH=arm64

# Kernel identity
export KERNEL_NAME="-VallyKernel"
export KBUILD_BUILD_USER="Rawzn"
export KBUILD_BUILD_HOST="VallyLab"

echo "===== CLONE KERNEL SOURCE ====="
git clone --depth=1 https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b peridot-u-oss kernel

cd kernel

echo "===== CLONE CLANG TOOLCHAIN ====="
git clone --depth=1 https://github.com/ZyCromerZ/Clang clang

# aktifkan toolchain
export CLANG_PATH="$(pwd)/clang"
export PATH="$CLANG_PATH/bin:$PATH"
# hapus linker konflik
rm -f clang/bin/ld || true

echo "===== INJECT KERNELSU NEXT ====="
git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next ksu
bash ksu/kernel/setup.sh

echo "===== FIX XIAOMI SOURCE BUG ====="
sed -i '/hwid\/Kconfig/d' drivers/misc/Kconfig || true
sed -i '/hwid/d' drivers/misc/Makefile || true

echo "===== BUILD DEFCONFIG ====="
make O=out ARCH=arm64 gki_defconfig

echo "===== DISABLE BTF ====="
scripts/config --file out/.config -d CONFIG_DEBUG_INFO_BTF
scripts/config --file out/.config -d CONFIG_DEBUG_INFO_BTF_MODULES

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

echo "===== UPDATE CONFIG ====="
make O=out ARCH=arm64 olddefconfig

make -j$(nproc) O=out \
ARCH=arm64 \
LLVM=1 \
LLVM_IAS=1 \
LOCALVERSION=$KERNEL_NAME \
KCFLAGS="-Wno-frame-larger-than"

cd ..

echo "===== CLONE ANYKERNEL ====="
git clone https://github.com/osm0sis/AnyKernel3 AnyKernel

echo "===== COPY KERNEL IMAGE ====="
cp kernel/out/arch/arm64/boot/Image.gz AnyKernel/

echo "===== CREATE FLASHABLE ZIP ====="
cd AnyKernel
zip -r PocoF6-HyperKernel.zip *

echo "===== BUILD SUCCESS ====="
