#!/usr/bin/env bash

set -e
set -x

export ARCH=arm64
export SUBARCH=arm64

WORKDIR=$(pwd)

echo "===== CLONE KERNEL SOURCE ====="
git clone --depth=1 https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b peridot-u-oss kernel
cd kernel

echo "===== SETUP CLANG ====="
git clone --depth=1 https://github.com/ZyCromerZ/Clang clang
export PATH="$(pwd)/clang/bin:$PATH"
rm -f clang/bin/ld || true

echo "===== DEFCONFIG ====="
make O=out ARCH=arm64 gki_defconfig

# ===============================
# 🔥 PATCH DROIDSPACE FEATURES
# ===============================
echo "===== ENABLE REQUIRED FEATURES ====="

scripts/config --file out/.config \
-e NAMESPACES \
-e PID_NS \
-e IPC_NS \
-e UTS_NS \
-e NET_NS \
-e DEVPTS_MULTIPLE_INSTANCES \
-e DEVTMPFS \
-e DEVTMPFS_MOUNT \
-e CGROUPS \
-e CGROUP_DEVICE \
-e CGROUP_PIDS \
-e CGROUP_FREEZER \
-e CGROUP_SCHED \
-e CGROUP_CPUACCT

echo "===== APPLY OLDDEFCONFIG ====="
make O=out ARCH=arm64 olddefconfig

echo "===== BUILD KERNEL ====="
make -j$(nproc) O=out ARCH=arm64 LLVM=1 LLVM_IAS=1

cd $WORKDIR

# ===============================
# 🔥 REPACK BOOT (A16 BASE)
# ===============================
echo "===== UNPACK STOCK BOOT ====="

git clone https://github.com/osm0sis/mkbootimg_tools tools

mkdir stock
cp boot.img stock/
cd stock

../tools/unpack_bootimg --boot_img boot.img --out out

echo "===== REPACK WITH NEW KERNEL ====="

../tools/mkbootimg \
--kernel ../kernel/out/arch/arm64/boot/Image.gz \
--ramdisk out/ramdisk \
--cmdline "$(cat out/cmdline)" \
--base $(cat out/base) \
--pagesize $(cat out/pagesize) \
--output ../new-boot.img

cd ..

echo "===== SHA256 ====="
sha256sum new-boot.img

echo "===== DONE BUILD ====="
