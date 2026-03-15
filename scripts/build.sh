#!/usr/bin/env bash

set -e
set -x

export ARCH=arm64
export SUBARCH=arm64

echo "===== CLONE KERNEL SOURCE ====="
git clone --depth=1 https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b peridot-u-oss kernel

echo "===== CLONE CLANG TOOLCHAIN ====="
git clone --depth=1 https://github.com/ZyCromerZ/Clang clang

echo "===== CLONE ANYKERNEL ====="
git clone --depth=1 https://github.com/osm0sis/AnyKernel3 AnyKernel

cd kernel

echo "===== INJECT KERNELSU NEXT ====="
git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next ksu
bash ksu/kernel/setup.sh

CONF=arch/arm64/configs/vendor/pineapple_defconfig

echo "===== ENABLE FEATURES ====="

cat <<EOF >> $CONF
CONFIG_KSU=y
CONFIG_KVM=y
CONFIG_KVM_ARM_HOST=y
CONFIG_VIRTUALIZATION=y
CONFIG_VHOST_NET=y
CONFIG_VSOCKETS=y
CONFIG_VIRTIO=y
CONFIG_OVERLAY_FS=y
CONFIG_TMPFS_XATTR=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_WIREGUARD=y
CONFIG_BPF=y
EOF

export PATH=$GITHUB_WORKSPACE/clang/bin:$PATH

echo "===== BUILD CONFIG ====="
make O=out vendor/pineapple_defconfig

echo "===== BUILD KERNEL ====="
make -j$(nproc) O=out CC=clang LLVM=1 LLVM_IAS=1

echo "===== COPY KERNEL ====="

cp out/arch/arm64/boot/Image ../AnyKernel/Image

cd ../AnyKernel

echo "===== BUILD FLASHABLE ZIP ====="

zip -r PocoF6-HyperKernel.zip *
