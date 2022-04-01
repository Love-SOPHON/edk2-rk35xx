#!/bin/bash

#/** @file
#
#  Build script for Rockchip EDK2
#
#  Copyright (c) 2022, Xilin Wu <wuxilin123@gmail.com>
#  Copyright (c) 2021-2022, BigfootACA <bigfoot@classfun.cn>
#
#  SPDX-License-Identifier: BSD-2-Clause-Patent
#
#**/

RK356X_DEVICES=(
	rock3a
)

RK3588_DEVICES=(
	dummy
)

function _help(){
	echo "Usage: build.sh --device DEV"
	echo
	echo "Build edk2 for Rockchip platform."
	echo
	echo "Options: "
	echo "	--device DEV, -d DEV:    build for DEV. (${RK356X_DEVICES[*]} ${RK3588_DEVICES[*]})"
	echo "	--all, -a:               build all devices."
	echo "	--chinese, -c:           use hub.fastgit.xyz for submodule cloning."
	echo "	--release MODE, -r MODE: Release mode for building, default is 'RELEASE', 'DEBUG' alternatively."
	echo "	--toolchain TOOLCHAIN:   Set toolchain, default is 'GCC5'."
	echo "	--clean, -C:             clean workspace and output."
	echo "	--distclean, -D:         clean up all files that are not in repo."
	echo "	--outputdir, -O:         output folder."
	echo "	--help, -h:              show this help."
	echo
	exit "${1}"
}

function _error(){ echo "${@}" >&2;exit 1; }

function _build(){
	local DEVICE="${1}"
	shift
	source "${_EDK2}/edksetup.sh"
	[ -d "${WORKSPACE}" ]||mkdir "${WORKSPACE}"
	set -x
	make -C "${_EDK2}/BaseTools"||exit "$?"
	# based on the instructions from edk2-platform
	case "${MODE}" in
		RELEASE)
			_MODE=RELEASE;;
		*)
			_MODE=DEBUG;;
	esac
	build \
		-s \
		-n 0 \
		-a AARCH64 \
		-t "${TOOLCHAIN}" \
		-p "custRkPkg/Devices/${DEVICE}.dsc" \
		-b "${_MODE}" \
		-D FIRMWARE_VER="${GITCOMMIT}" \
		||return "$?"
	echo "Build done"
	set +x
}

function _build_idblock(){
	echo " => Building idblock.bin"
	FLASHFILES="FlashHead.bin FlashData.bin FlashBoot.bin"
	rm -f idblock.bin rk35*_ddr_*.bin rk35*_usbplug*.bin UsbHead.bin ${FLASHFILES}

	# Default DDR image uses 1.5M baud. Patch it to use 115200 to match UEFI first.
	cat `pwd`/rkbin/tools/ddrbin_param.txt					 		\
		| sed 's/^uart baudrate=.*$/uart baudrate=115200/'  		\
		| sed 's/^dis_printf_training=.*$/dis_printf_training=1/' 	\
		> `pwd`/workspace/ddrbin_param.txt
	./rkbin/tools/ddrbin_tool `pwd`/workspace/ddrbin_param.txt rkbin/${DDR}

	# Create idblock.bin
	# Generate spl_loader
	(cd rkbin && ./tools/boot_merger RKBOOT/${MINIALL_INI})
	./rkbin/tools/boot_merger unpack --loader rkbin/${SOC}_spl_loader_*.bin --output .
	cat ${FLASHFILES} > idblock.bin
	(cd rkbin && git checkout ${DDR})

	# Cleanup
	rm -f rkbin/rk35*_spl_loader_*.bin
	rm -f rk35*_ddr_*.bin rk35*_usbplug*.bin UsbHead.bin ${FLASHFILES}
	echo " => idblock.bin build done"
}

function _build_fit(){
	echo " => Building FIT"
	./scripts/extractbl31.py rkbin/${BL31}
	cp -f workspace/Build/custRkPkg/${_MODE}_GCC5/FV/CUSTRKPKG_UEFI.fd workspace/CUSTRKPKG_EFI.fd
	cat uefi_${SOC}.its | sed "s,@DEVICE@,${DEVICE},g" > ${SOC}_${DEVICE}_EFI.its
	./rkbin/tools/mkimage -f ${SOC}_${DEVICE}_EFI.its ${DEVICE}_EFI.itb
	rm -f bl31_0x*.bin workspace/CUSTRKPKG_EFI.fd ${SOC}_${DEVICE}_EFI.its
	echo " => FIT build done"
}

function _clean(){
	rm --one-file-system --recursive --force ./workspace idblock.bin *.itb uefi-*.img*; 
}

function _distclean(){
	if [ -d .git ];then git clean -xdf;else _clean;fi; 
}

cd "$(dirname "$0")"||exit 1
typeset -l DEVICE
typeset -u MODE
DEVICE=""
MODE=RELEASE
CHINESE=false
CLEAN=false
DISTCLEAN=false
TOOLCHAIN=GCC5
export OUTDIR="${PWD}"
OPTS="$(getopt -o t:d:hacACDO:r:u -l toolchain:,device:,help,all,chinese,clean,distclean,outputdir:,release: -n 'build.sh' -- "$@")"||exit 1
eval set -- "${OPTS}"
while true
do	case "${1}" in
		-d|--device)
			DEVICE="${2}";shift 2;;
		-a|--all) 
			DEVICE=all;shift;;
		-c|--chinese)
			CHINESE=true;shift;;
		-C|--clean)
			CLEAN=true;shift;;
		-D|--distclean)
			DISTCLEAN=true;shift;;
		-O|--outputdir)
			OUTDIR="${2}";shift 2;;
		-r|--release)
			MODE="${2}";shift 2;;
		-t|--toolchain)
			TOOLCHAIN="${2}";shift 2;;
		-h|--help)
			_help 0;shift;;
		--)
			shift;break;;
		*)
			_help 1;;
	esac
done
if "${DISTCLEAN}";then _distclean;exit "$?";fi
if "${CLEAN}";then _clean;exit "$?";fi
[ -z "${DEVICE}" ]&&_help 1
if ! [ -f edk2/edksetup.sh ] || ! [ -f ../edk2/edksetup.sh ]
then	set -e
	echo "Updating submodules"
	if "${CHINESE}"
	then	git submodule set-url edk2                         https://hub.fastgit.xyz/tianocore/edk2.git
		git submodule set-url edk2-platforms               https://hub.fastgit.xyz/tianocore/edk2-platforms.git
		git submodule set-url custRkPkg/Library/SimpleInit https://hub.fastgit.xyz/BigfootACA/simple-init.git
		git submodule set-url rkbin                        https://hub.fastgit.xyz/Caesar-github/rkbin.git
		git submodule init;git submodule update --depth 1
		pushd edk2

		git submodule set-url ArmPkg/Library/ArmSoftFloatLib/berkeley-softfloat-3   https://hub.fastgit.xyz/ucb-bar/berkeley-softfloat-3.git
		git submodule set-url CryptoPkg/Library/OpensslLib/openssl                  https://hub.fastgit.xyz/openssl/openssl.git
		git submodule set-url BaseTools/Source/C/BrotliCompress/brotli              https://hub.fastgit.xyz/google/brotli.git
		git submodule set-url UnitTestFrameworkPkg/Library/CmockaLib/cmocka         https://hub.fastgit.xyz/tianocore/edk2-cmocka.git
		git submodule set-url ArmPkg/Library/ArmSoftFloatLib/berkeley-softfloat-3   https://hub.fastgit.xyz/ucb-bar/berkeley-softfloat-3.git
		git submodule set-url MdeModulePkg/Library/BrotliCustomDecompressLib/brotli https://hub.fastgit.xyz/google/brotli.git
		git submodule set-url MdeModulePkg/Universal/RegularExpressionDxe/oniguruma https://hub.fastgit.xyz/kkos/oniguruma.git
		git submodule set-url RedfishPkg/Library/JsonLib/jansson                    https://hub.fastgit.xyz/akheron/jansson.git
		git submodule init;git submodule update
		git checkout .gitmodules
		popd
		pushd custRkPkg/Library/SimpleInit
		git submodule set-url libs/lvgl     https://hub.fastgit.xyz/lvgl/lvgl.git
		git submodule set-url libs/lodepng  https://hub.fastgit.xyz/lvandeve/lodepng.git
		git submodule set-url libs/freetype https://hub.fastgit.xyz/freetype/freetype.git
		git submodule set-url libs/nanosvg  https://hub.fastgit.xyz/memononen/nanosvg.git
		git submodule init;git submodule update
		popd
		git checkout .gitmodules
	else	git submodule init;git submodule update --depth 1
		pushd edk2
		git submodule init;git submodule update
		popd
		pushd custRkPkg/Library/SimpleInit
		git submodule init;git submodule update
		popd
	fi
	set +e
fi
for i in "${EDK2}" ./edk2 ../edk2
do	if [ -n "${i}" ]&&[ -f "${i}/edksetup.sh" ]
	then	_EDK2="$(realpath "${i}")"
		break
	fi
done
for i in "${EDK2_PLATFORMS}" ./edk2-platforms ../edk2-platforms
do	if [ -n "${i}" ]&&[ -d "${i}/Platform" ]
	then	_EDK2_PLATFORMS="$(realpath "${i}")"
		break
	fi
done
for i in "${SIMPLE_INIT}" custRkPkg/Library/SimpleInit ./simple-init ../simple-init
do	if [ -n "${i}" ]&&[ -f "${i}/SimpleInit.inc" ]
	then	_SIMPLE_INIT="$(realpath "${i}")"
		break
	fi
done
[ -n "${_EDK2}" ]||_error "EDK2 not found, please read README.md"
[ -n "${_EDK2_PLATFORMS}" ]||_error "EDK2 Platforms not found, please read README.md"
[ -n "${_SIMPLE_INIT}" ]||_error "SimpleInit not found, please read README.md"
echo "EDK2 Path: ${_EDK2}"
echo "EDK2_PLATFORMS Path: ${_EDK2_PLATFORMS}"
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
export GCC5_AARCH64_PREFIX="${CROSS_COMPILE}"
export CLANG38_AARCH64_PREFIX="${CROSS_COMPILE}"
export PACKAGES_PATH="$_EDK2:$_EDK2_PLATFORMS:$_SIMPLE_INIT:$PWD"
export WORKSPACE="${PWD}/workspace"

GITCOMMIT="$(git describe --tags --always)"||GITCOMMIT="unknown"
export GITCOMMIT
export DEVICES=("${RK356X_DEVICES[@]}" "${RK3588_DEVICES[@]}")
set -e
mkdir -p "${_SIMPLE_INIT}/build" "${_SIMPLE_INIT}/root/usr/share/locale"
for i in "${_SIMPLE_INIT}/po/"*.po
do	[ -f "${i}" ]||continue
	_name="$(basename "$i" .po)"
	_path="${_SIMPLE_INIT}/root/usr/share/locale/${_name}/LC_MESSAGES"
	mkdir -p "${_path}"
	msgfmt -o "${_path}/simple-init.mo" "${i}"
done
bash "${_SIMPLE_INIT}/scripts/gen-rootfs-source.sh" \
	"${_SIMPLE_INIT}" \
	"${_SIMPLE_INIT}/build"
if [ "${DEVICE}" == "all" ]
then	E=0
	for i in "${DEVICES[@]}"
	do	echo "Building ${i}"
		rm --recursive --force --one-file-system ./workspace||true
		_build "${i}"||E="$?"
	done
	exit "${E}"
else	HAS=false
	for i in "${RK356X_DEVICES[@]}"
	do	[ "${i}" == "${DEVICE}" ]||continue
		HAS=true
		SOC=rk356x
		MINIALL_INI=RK3568MINIALL.ini
		TRUST_INI=RK3568TRUST.ini
		break
	done
	for i in "${RK3588_DEVICES[@]}"
	do	[ "${i}" == "${DEVICE}" ]||continue
		HAS=true
		SOC=rk3588
		break
	done
	[ "${HAS}" == "true" ]||_error "build.sh: unknown build target device ${DEVICE}."
	_build "${DEVICE}"
fi

BL31=$(grep '^PATH=.*_bl31_' rkbin/RKTRUST/${TRUST_INI} | cut -d = -f 2-)
DDR=$(grep '^Path1=.*_ddr_' rkbin/RKBOOT/${MINIALL_INI} | cut -d = -f 2-)
test -r rkbin/${BL31} || (echo "rkbin/${BL31} not found"; false)

_build_fit

_build_idblock