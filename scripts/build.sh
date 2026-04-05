#!/usr/bin/env bash

set -e
set -x

export ARCH=arm64
export SUBARCH=arm64
export GIT_TERMINAL_PROMPT=0
git config --global advice.detachedHead false
git config --global --add safe.directory '*'

WORKDIR=$(pwd)

echo "===== CLONE KERNEL SOURCE ====="
git clone --depth=1 https://github.com/MiCode/Xiaomi_Kernel_OpenSource -b peridot-u-oss kernel
cd kernel

echo "===== SETUP CLANG ====="
git clone --depth=1 https://github.com/ZyCromerZ/Clang clang
export PATH="$(pwd)/clang/bin:$PATH"
rm -f clang/bin/ld || true

# ===============================
# 🔥 FIX HWID ERROR (WAJIB)
# ===============================
echo "===== FIX HWID ====="

sed -i '/hwid/d' drivers/misc/Kconfig || true
sed -i '/hwid/d' drivers/misc/Makefile || true

mkdir -p drivers/misc/hwid

cat <<EOF > drivers/misc/hwid/Kconfig
config HWID_DUMMY
    bool "Dummy HWID"
    default n
EOF

cat <<EOF > drivers/misc/hwid/Makefile
obj-\$(CONFIG_HWID_DUMMY) += dummy.o
EOF

touch drivers/misc/hwid/dummy.c

# ===============================
# 🔥 DEFCONFIG
# ===============================
echo "===== DEFCONFIG ====="
make O=out ARCH=arm64 gki_defconfig

# ===============================
# 🔥 DROIDSPACE FULL SUPPORT
# ===============================
echo "===== ENABLE DROIDSPACE FEATURES ====="

scripts/config --file out/.config \
-e NAMESPACES \
-e PID_NS \
-e IPC_NS \
-e UTS_NS \
-e NET_NS \
-e USER_NS \
-e DEVPTS_MULTIPLE_INSTANCES \
-e DEVTMPFS \
-e DEVTMPFS_MOUNT \
-e CGROUPS \
-e CGROUP_DEVICE \
-e CGROUP_PIDS \
-e CGROUP_FREEZER \
-e CGROUP_SCHED \
-e CGROUP_CPUACCT \
-e CGROUP_BPF \
-e CGROUP_MISC \
-e CGROUP_NET_PRIO \
-e CGROUP_NET_CLASSID \
-e CGROUP_HUGETLB \
-e MEMCG \
-e BLK_CGROUP \
-e CFS_BANDWIDTH \
-e FAIR_GROUP_SCHED \
-e RT_GROUP_SCHED

echo "===== DISABLE BTF ====="

scripts/config --file out/.config -d CONFIG_DEBUG_INFO_BTF
scripts/config --file out/.config -d CONFIG_DEBUG_INFO_BTF_MODULES
scripts/config --file out/.config -d CONFIG_PAHOLE_HAS_SPLIT_BTF

echo "===== APPLY OLDDEFCONFIG ====="
make O=out ARCH=arm64 olddefconfig

echo "===== DISABLE STRICT WARNINGS ====="

scripts/config --file out/.config -d CONFIG_WERROR || true

# ===============================
# 🔥 BUILD KERNEL
# ===============================
echo "===== BUILD KERNEL ====="
make -j$(nproc) O=out \
ARCH=arm64 \
LLVM=1 \
LLVM_IAS=1 \
KCFLAGS="-Wno-frame-larger-than"

cd $WORKDIR

# ===============================
# 🔥 AMBIL BOOT DARI REPO LU
# ===============================
echo "===== GET STOCK BOOT (A16) ====="

wget -O boot.img https://raw.githubusercontent.com/sntdashi/vally-kernel-poco-f6/main/boot.img

# ===============================
# 🔥 UNPACK
# ===============================
echo "===== UNPACK STOCK BOOT ====="
echo "===== SETUP MKBOOTIMG (AOSP) ====="

git clone --depth=1 https://android.googlesource.com/platform/system/tools/mkbootimg mkbootimg_tools

cd mkbootimg_tools
chmod +x mkbootimg.py unpack_bootimg.py
cd ..

mkdir stock
mv boot.img stock/
cd stock

python3 mkbootimg_tools/unpack_bootimg.py --boot_img boot.img --out out

# ===============================
# 🔥 REPACK (ANTI BOOTLOOP)
# ===============================
echo "===== REPACK NEW BOOT ====="

python3 mkbootimg_tools/mkbootimg.py \
--kernel ../kernel/out/arch/arm64/boot/Image.gz \
--ramdisk out/ramdisk \
--cmdline "$(cat out/cmdline)" \
--base $(cat out/base) \
--pagesize $(cat out/pagesize) \
--os_version 16.0.0 \
--os_patch_level 2024-01 \
--header_version 4 \
--output ../new-boot.img

cd ..

echo "===== SHA256 ====="
sha256sum new-boot.img

echo "===== BUILD DONE BRO 🔥 ====="
