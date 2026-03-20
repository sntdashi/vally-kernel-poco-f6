#!/usr/bin/env bash

set -e
set -x

export ARCH=arm64
export SUBARCH=arm64

# Kernel identity
export KERNEL_NAME="-VallyKernel"
export KBUILD_BUILD_USER="Rawzn"
export KBUILD_BUILD_HOST="VallyLab"

WORKDIR=$(pwd)

echo "===== CLONE KERNEL SOURCE (Poco F6 Android 16) ====="
# Mengambil kernel sumber dari Poco F6 untuk Android 16
git clone --depth=1 https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b peridot-u-oss kernel
cd kernel

echo "===== CLONE CLANG TOOLCHAIN ====="
# Mengambil toolchain Clang
git clone --depth=1 https://github.com/ZyCromerZ/Clang clang
export CLANG_PATH="$(pwd)/clang"
export PATH="$CLANG_PATH/bin:$PATH"
rm -f clang/bin/ld || true

echo "===== INJECT KERNELSU NEXT ====="
# Mengintegrasikan KernelSU
git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next ksu
bash ksu/kernel/setup.sh

echo "===== FIX XIAOMI SOURCE BUG ====="
# Memperbaiki bug di repo kernel Xiaomi (kalau ada)
sed -i '/hwid\/Kconfig/d' drivers/misc/Kconfig || true
sed -i '/hwid/d' drivers/misc/Makefile || true

echo "===== BUILD DEFCONFIG ====="
# Menggunakan defconfig dari kernel yang sudah ditentukan untuk Poco F6 Android 16
make O=out ARCH=arm64 gki_defconfig

echo "===== DISABLE BTF ====="
# Menonaktifkan BTF untuk menghindari error
scripts/config --file out/.config -d CONFIG_DEBUG_INFO_BTF
scripts/config --file out/.config -d CONFIG_DEBUG_INFO_BTF_MODULES

echo "===== ENABLE FEATURES ====="
# Mengaktifkan beberapa fitur kernel
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
# Update konfigurasi kernel
make O=out ARCH=arm64 olddefconfig

echo "===== BUILD KERNEL ====="
# Build kernel dengan Clang
make -j$(nproc) O=out \
ARCH=arm64 \
LLVM=1 \
LLVM_IAS=1 \
LOCALVERSION=$KERNEL_NAME \
KCFLAGS="-Wno-frame-larger-than"

cd $WORKDIR

echo "===== CLONE ANYKERNEL3 ====="
# Mengambil AnyKernel3 untuk flashable zip
git clone --depth=1 https://github.com/osm0sis/AnyKernel3 AnyKernel

echo "===== COPY KERNEL IMAGE ====="
# Menyalin hasil kernel image yang sudah dibuild ke folder AnyKernel
cp kernel/out/arch/arm64/boot/Image.gz AnyKernel/Image.gz

echo "===== COPY ADDITIONAL FILES (boot, vendor, dtbo) ====="
# Menyalin boot, vendor, dan dtbo dari repo kamu ke AnyKernel
cp https://github.com/sntdashi/vally-kernel-poco-f6/boot.img AnyKernel/boot.img
cp https://github.com/sntdashi/vally-kernel-poco-f6/vendor_boot.img AnyKernel/vendor_boot.img
cp https://github.com/sntdashi/vally-kernel-poco-f6/dtbo.img AnyKernel/dtbo.img

echo "===== UPDATE ANYKERNEL.SH ====="
# Memperbarui kernel string dan device check di AnyKernel
sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} by VallyLab @ xda-developers/" AnyKernel/anykernel.sh
sed -i "s/do.devicecheck=.*/do.devicecheck=1/" AnyKernel/anykernel.sh

echo "===== CREATE FLASHABLE ZIP ====="
# Membuat flashable zip dari AnyKernel
cd AnyKernel
zip -r "../PocoF6-HyperKernel.zip" *

echo "===== BUILD SUCCESS ====="
echo "Zip ready: $WORKDIR/PocoF6-HyperKernel.zip"
