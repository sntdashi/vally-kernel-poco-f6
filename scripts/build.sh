#!/usr/bin/env bash

set -e
set -x

# Definisikan ARCH dan SUBARCH
export ARCH=arm64
export SUBARCH=arm64

# Identitas kernel dan informasi build
export KERNEL_NAME="-VallyKernel"
export KBUILD_BUILD_USER="Rawzn"
export KBUILD_BUILD_HOST="VallyLab"

WORKDIR=$(pwd)

echo "===== CLONE KERNEL SOURCE (Poco F6 Android 16) ====="
# Ambil source kernel dari repo Poco F6 untuk Android 16
git clone --depth=1 https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b peridot-u-oss kernel
cd kernel

echo "===== CLONE CLANG TOOLCHAIN ====="
# Ambil toolchain Clang untuk kompilasi kernel
git clone --depth=1 https://github.com/ZyCromerZ/Clang clang
export CLANG_PATH="$(pwd)/clang"
export PATH="$CLANG_PATH/bin:$PATH"
rm -f clang/bin/ld || true

echo "===== INJECT KERNELSU NEXT ====="
# Integrasi KernelSU Next
git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next ksu
bash ksu/kernel/setup.sh

echo "===== FIX XIAOMI SOURCE BUG ====="
# Perbaiki bug pada repo kernel Xiaomi
sed -i '/hwid\/Kconfig/d' drivers/misc/Kconfig || true
sed -i '/hwid/d' drivers/misc/Makefile || true

echo "===== BUILD DEFCONFIG ====="
# Gunakan defconfig standar untuk build kernel
make O=out ARCH=arm64 gki_defconfig

echo "===== DISABLE BTF ====="
# Menonaktifkan BTF agar tidak terjadi masalah pada kernel
scripts/config --file out/.config -d CONFIG_DEBUG_INFO_BTF
scripts/config --file out/.config -d CONFIG_DEBUG_INFO_BTF_MODULES

echo "===== ENABLE ADDITIONAL FEATURES ====="
# Mengaktifkan berbagai fitur yang dibutuhkan untuk perangkat kamu
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
-e BPF \
-e PID_NS \
-e IPC_NS \
-e DEVPTS_FS_MOUNT \
-e CGROUP_DEVICES

echo "===== UPDATE CONFIG ====="
# Update konfigurasi dengan defconfig terbaru
make O=out ARCH=arm64 olddefconfig

echo "===== BUILD KERNEL ====="
# Proses build kernel dengan Clang
make -j$(nproc) O=out \
ARCH=arm64 \
LLVM=1 \
LLVM_IAS=1 \
LOCALVERSION=$KERNEL_NAME \
KCFLAGS="-Wno-frame-larger-than"

# Kembali ke direktori awal
cd $WORKDIR

echo "===== CLONE ANYKERNEL3 ====="
# Mengambil AnyKernel3 untuk membuat flashable zip
git clone --depth=1 https://github.com/osm0sis/AnyKernel3 AnyKernel

echo "===== COPY KERNEL IMAGE ====="
# Menyalin image kernel hasil build ke dalam folder AnyKernel
cp kernel/out/arch/arm64/boot/Image.gz AnyKernel/Image.gz

echo "===== COPY ADDITIONAL FILES (boot, vendor, dtbo) ====="
# Menyalin boot, vendor, dan dtbo dari repo kamu (gunakan URL raw GitHub)
cp https://github.com/sntdashi/vally-kernel-poco-f6/raw/main/boot.img AnyKernel/boot.img
cp https://github.com/sntdashi/vally-kernel-poco-f6/raw/main/vendor_boot.img AnyKernel/vendor_boot.img
cp https://github.com/sntdashi/vally-kernel-poco-f6/raw/main/dtbo.img AnyKernel/dtbo.img

echo "===== UPDATE ANYKERNEL.SH ====="
# Memperbarui kernel string dan device check di AnyKernel
sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} by VallyLab @ xda-developers/" AnyKernel/anykernel.sh
sed -i "s/do.devicecheck=.*/do.devicecheck=1/" AnyKernel/anykernel.sh

echo "===== CREATE FLASHABLE ZIP ====="
# Membuat file flashable zip dari AnyKernel
cd AnyKernel
zip -r "../PocoF6-HyperKernel.zip" *

echo "===== BUILD SUCCESS ====="
echo "Flashable ZIP siap: $WORKDIR/PocoF6-HyperKernel.zip"
