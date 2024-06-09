#!/bin/bash

#set -e

KERNELDIR=$(pwd)
KERNELNAME=TheOneMemory
CODENAME=Hayzel
VARIANT=EAS
BASE=EOL
DEVICENAME=X00TD

#sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-TheOneMemory/HeterogeneousMultiProcessing"/g' arch/arm64/configs/X00TD_defconfig
#sed -i "s/CONFIG_WIREGUARD=.*/# CONFIG_WIREGUARD is not set/g" arch/arm64/configs/X00TD_defconfig

TG_SUPER=0
BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot$TG_TOKEN/sendDocument"

tg_post_msg(){
        if [ $TG_SUPER = 1 ]
        then
            curl -s -X POST "$BOT_MSG_URL" \
            -d chat_id="$TG_CHAT_ID" \
            -d message_thread_id="$TG_TOPIC_ID" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1"
        else
            curl -s -X POST "$BOT_MSG_URL" \
            -d chat_id="$TG_CHAT_ID" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1"
        fi
}

tg_post_build()
{
	if [ $TG_SUPER = 1 ]
	then
	    curl -F document=@"$1" "$BOT_BUILD_URL" \
	    -F chat_id="$TG_CHAT_ID"  \
	    -F message_thread_id="$TG_TOPIC_ID" \
	    -F "disable_web_page_preview=true" \
	    -F "parse_mode=Markdown" \
	    -F caption="$2"
	else
	    curl -F document=@"$1" "$BOT_BUILD_URL" \
	    -F chat_id="$TG_CHAT_ID"  \
	    -F "disable_web_page_preview=true" \
	    -F "parse_mode=Markdown" \
	    -F caption="$2"
	fi
}

tg_post_msg "$(date '+%d %b %Y, %H:%M %Z')%0A%0ABuilding $KERNELNAME Kernel for $DEVICENAME%0ABuild URL <a href='$CIRCLE_BUILD_URL'>Here</a>"

if ! [ -d "$KERNELDIR/trb_clang" ]; then
  echo "trb_clang not found! Cloning..."
  # if ! git clone https://gitlab.com/varunhardgamer/trb_clang --depth=1 -b 17 --single-branch trb_clang; then
  if ! git clone https://gitlab.com/Tiktodz/electrowizard-clang.git --depth=1 -b 16 --single-branch trb_clang; then
  # mkdir -p trb_clang && cd trb_clang
  # bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S=11032023
  # cd ..
  # if ! [ -f "$KERNELDIR/trb_clang/bin/clang" ]; then
    echo "Cloning failed! Aborting..."
    exit 1
  fi
fi

## Copy this script inside the kernel directory
KERNEL_DEFCONFIG=darkonah_defconfig
DATE=$(date '+%Y%m%d')
FINAL_KERNEL_ZIP="$KERNELNAME-$BASE-$VARIANT-$(date '+%Y%m%d-%H%M')"
KERVER=$(make kernelversion)
export KBUILD_BUILD_TIMESTAMP=$(date)
export PATH="$KERNELDIR/trb_clang/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="queen"
#export KBUILD_BUILD_HOST=$(source /etc/os-release && echo "${NAME}" | cut -d" " -f1)
#export KBUILD_COMPILER_STRING="TheRagingBeast LLVM 17.0.0 #StayRaged™"
export KBUILD_COMPILER_STRING="$($KERNELDIR/trb_clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

# Speed up build process
MAKE="./makeparallel"

BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

# Java
command -v java > /dev/null 2>&1

# Clean build always lol
# echo -e "$yellow**** Cleaning ****"
mkdir -p out
make O=out clean

echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
echo -e "$cyan***********************************************"
echo    "                    BUILDING KERNEL                 "
echo -e "**********************************************$nocol"
make $KERNEL_DEFCONFIG O=out 2>&1 | tee -a error.log
make -j$(nproc --all) O=out LLVM=1\
		ARCH=arm64 \
		SUBARCH=arm64 \
		AS="$KERNELDIR/trb_clang/bin/llvm-as" \
		CC="$KERNELDIR/trb_clang/bin/clang" \
		HOSTCC="$KERNELDIR/trb_clang/bin/clang" \
		HOSTCXX="$KERNELDIR/trb_clang/bin/clang++" \
		LD="$KERNELDIR/trb_clang/bin/ld.lld" \
		AR="$KERNELDIR/trb_clang/bin/llvm-ar" \
		NM="$KERNELDIR/trb_clang/bin/llvm-nm" \
		STRIP="$KERNELDIR/trb_clang/bin/llvm-strip" \
		OBJCOPY="$KERNELDIR/trb_clang/bin/llvm-objcopy" \
		OBJDUMP="$KERNELDIR/trb_clang/bin/llvm-objdump" \
		CROSS_COMPILE="$KERNELDIR/trb_clang/bin/clang" \
		CROSS_COMPILE_COMPAT="$KERNELDIR/trb_clang/bin/clang" \
		CROSS_COMPILE_ARM32="$KERNELDIR/trb_clang/bin/clang" 2>&1 | tee -a error.log


BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

echo -e "$red**** Kernel Compilation Completed ****$nocol"
echo -e "$red**** Verify Image.gz-dtb ****$nocol"

if ! [ -f $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb ];then
    tg_post_build "error.log" "Compile Error!!"
    echo "$red Compile Failed!!!$nocol"
    exit 1
fi

# Anykernel3 time!!
echo -e "$red**** Verifying AnyKernel3 Directory ****$nocol"
if ! [ -d "$KERNELDIR/AnyKernel3" ]; then
  echo "AnyKernel3 not found! Cloning..."
  if ! git clone --depth=1 -b zeus https://github.com/Tiktodz/AnyKernel3 -b eas AnyKernel3; then
    tg_post_build "$KERNELDIR/out/arch/arm64/boot/Image.gz-dtb" "Failed to Clone Anykernel, Sending image file instead"
    echo "Cloning failed! Aborting..."
    exit 1
  fi
fi

ANYKERNEL3_DIR=$KERNELDIR/AnyKernel3/

# Generating Changelog
echo "<b><#selectbg_g>$(date)</#></b>" > changelog
git log --oneline -n15 | cut -d " " -f 2- | awk '{print "<*> " $(A) "</*>"}' | tee -a changelog

echo "**** Copying Image.gz-dtb ****"
cp $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb $ANYKERNEL3_DIR/

echo -e "$red**** Time to zip up! ****$nocol"
cd $ANYKERNEL3_DIR/
cp -af $KERNEL_DIR/init.$CODENAME.Spectrum.rc spectrum/init.spectrum.rc && sed -i "s/persist.spectrum.kernel.*/persist.spectrum.kernel TheOneMemory/g" spectrum/init.spectrum.rc
cp -af $KERNEL_DIR/changelog META-INF/com/google/android/aroma/changelog.txt
cp -af anykernel-real.sh anykernel.sh
sed -i "s/kernel.string=.*/kernel.string=$KERNELNAME/g" anykernel.sh
sed -i "s/kernel.type=.*/kernel.type=$VARIANT/g" anykernel.sh
sed -i "s/kernel.for=.*/kernel.for=$CODENAME/g" anykernel.sh
sed -i "s/kernel.compiler=.*/kernel.compiler=$KBUILD_COMPILER_STRING/g" anykernel.sh
sed -i "s/kernel.made=.*/kernel.made=dotkit @fakedotkit/g" anykernel.sh
sed -i "s/kernel.version=.*/kernel.version=$KERVER/g" anykernel.sh
sed -i "s/message.word=.*/message.word=Appreciate your efforts for choosing TheOneMemory kernel./g" anykernel.sh
sed -i "s/build.date=.*/build.date=$DATE/g" anykernel.sh
sed -i "s/build.type=.*/build.type=$BASE/g" anykernel.sh
sed -i "s/supported.versions=.*/supported.versions=9-13/g" anykernel.sh
sed -i "s/device.name1=.*/device.name1=X00TD/g" anykernel.sh
sed -i "s/device.name2=.*/device.name2=X00T/g" anykernel.sh
sed -i "s/device.name3=.*/device.name3=Zenfone Max Pro M1 (X00TD)/g" anykernel.sh
sed -i "s/device.name4=.*/device.name4=ASUS_X00TD/g" anykernel.sh
sed -i "s/device.name5=.*/device.name5=ASUS_X00T/g" anykernel.sh
sed -i "s/X00TD=.*/X00TD=1/g" anykernel.sh
cd META-INF/com/google/android
sed -i "s/KNAME/$KERNELNAME/g" aroma-config
sed -i "s/KVER/$KERVER/g" aroma-config
sed -i "s/KAUTHOR/dotkit @fakedotkit/g" aroma-config
sed -i "s/KDEVICE/Zenfone Max Pro M1/g" aroma-config
sed -i "s/KBDATE/$DATE/g" aroma-config
sed -i "s/KVARIANT/$VARIANT/g" aroma-config
cd ../../../..

zip -r9 "../$FINAL_KERNEL_ZIP" * -x .git README.md placeholder anykernel-real.sh .gitignore zipsigner* "*.zip"

## Prepare a final zip variable
ZIP_FINAL="$FINAL_KERNEL_ZIP"

echo -e "$yellow|| Signing Zip ||$nocol"
tg_post_msg "<code>Signing Zip file with AOSP keys..</code>"

cd ..

curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
ZIP_FINAL="$ZIP_FINAL-signed"

echo -e "$red**** Uploading your zip now ****$nocol"
tg_post_build "$ZIP_FINAL.zip" "*Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)*

\`\`\`Latest Changelog
$(git log --oneline -n5 | cut -d" " -f2- | awk '{print "• " $(A)}')
\`\`\`"
