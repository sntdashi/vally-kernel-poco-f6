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

echo "===== CLONE KERNEL SOURCE ====="
git clone --depth=1 https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b peridot-u-oss kernel
cd kernel

echo "===== FIX MISSING HWID ====="
sed -i '/hwid\/Kconfig/d' drivers/misc/Kconfig || true

echo "===== CLONE CLANG TOOLCHAIN ====="
git clone --depth=1 https://github.com/ZyCromerZ/Clang clang
export CLANG_PATH="$(pwd)/clang"
export PATH="$CLANG_PATH/bin:$PATH"
rm -f clang/bin/ld || true

echo "===== INJECT KERNELSU NEXT ====="
git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next ksu
bash ksu/kernel/setup.sh

echo "===== BUILD DEFCONFIG ====="
make O=out ARCH=arm64 gki_defconfig

echo "===== FIX CONFIG (ANTI ERROR) ====="

# disable problematic debug
scripts/config --file out/.config \
-d CONFIG_DEBUG_INFO_BTF \
-d CONFIG_DEBUG_INFO_BTF_MODULES

# fix stack frame error
scripts/config --file out/.config \
--set-val CONFIG_FRAME_WARN 4096

# disable problematic features
scripts/config --file out/.config \
-d CONFIG_BPF \
-d CONFIG_USB_GADGET \
-d CONFIG_USB_CONFIGFS

# enable fitur penting
scripts/config --file out/.config \
-e CONFIG_KSU \
-e CONFIG_KVM \
-e CONFIG_VIRTUALIZATION \
-e CONFIG_VHOST_NET \
-e CONFIG_VSOCKETS \
-e CONFIG_VIRTIO \
-e CONFIG_OVERLAY_FS \
-e CONFIG_TMPFS_XATTR \
-e CONFIG_ANDROID_BINDERFS \
-e CONFIG_WIREGUARD

echo "===== UPDATE CONFIG ====="
make O=out ARCH=arm64 olddefconfig

echo "===== BUILD KERNEL ====="
make -j$(nproc) O=out \
ARCH=arm64 \
LLVM=1 \
LLVM_IAS=1 \
LOCALVERSION=$KERNEL_NAME \
KCFLAGS="-Wno-error -Wno-frame-larger-than"

cd $WORKDIR

echo "===== PACK BOOT IMAGE ====="

# install dependencies
sudo apt-get update
sudo apt-get install -y android-sdk-libsparse-utils

# ambil boot.img
cp boot.img stock_boot.img

# extract ramdisk & info pakai magiskboot (lebih stabil)
wget https://github.com/topjohnwu/Magisk/releases/latest/download/magiskboot -O magiskboot
chmod +x magiskboot

./magiskboot unpack stock_boot.img

# replace kernel
cp Image.gz kernel

# repack
./magiskboot repack stock_boot.img new-boot.img

echo "===== EXTRACT IMAGE ====="
cp kernel/out/arch/arm64/boot/Image.gz ./Image.gz

echo "===== PACK BOOT IMAGE ====="

# install tools
sudo apt-get update
sudo apt-get install -y android-sdk-libsparse-utils

# clone mkbootimg tools (fix auth issue)
rm -rf mkboot
# Gunakan link alternatif untuk magiskboot
wget https://github.com/itachi-0100/Magisk/releases/download/v30.7/magiskboot -O magiskboot

# ambil magiskboot dari source (fix 404)
rm -rf magisk
git clone https://github.com/topjohnwu/Magisk.git magisk
cp magisk/tools/magiskboot magiskboot
chmod +x magiskboot

# backup boot
cp boot.img stock_boot.img

# unpack boot.img dari repo lo
./unpack_bootimg.py ../boot.img

# replace kernel
cp ../Image.gz kernel

# repack
./mkbootimg.py \
--kernel kernel \
--ramdisk ramdisk \
--dtb dtb \
--cmdline "$(cat cmdline)" \
--base $(cat base) \
--pagesize $(cat pagesize) \
--output ../new-boot.img

cd ..

echo "===== DONE ====="
echo "OUTPUT: new-boot.img"
