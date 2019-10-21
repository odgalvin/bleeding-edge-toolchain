#!/bin/sh
# shellcheck disable=SC2030,SC2031

#
# file: build-bleeding-edge-toolchain.sh
#
# author: Copyright (C) 2016-2019 Freddie Chopin http://www.freddiechopin.info http://www.distortec.com
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
# distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#

set -eu

binutilsVersion="2.32"
expatVersion="2.2.7"
gccVersion="9.2.0"
gdbVersion="8.3"
gmpVersion="6.1.2"
islVersion="0.21"
libiconvVersion="1.16"
mpcVersion="1.1.0"
mpfrVersion="4.0.2"
newlibVersion="3.1.0"
pythonVersion="2.7.16"
zlibVersion="1.2.11"

top="$(pwd)"
buildNative="buildNative"
buildWin32="buildWin32"
buildWin64="buildWin64"
installNative="installNative"
installWin32="installWin32"
installWin64="installWin64"
nanoLibraries="nanoLibraries"
prerequisites="prerequisites"
sources="sources"

binutils="binutils-$binutilsVersion"
binutilsArchive="$binutils.tar.xz"
expat="expat-$expatVersion"
expatArchive="$expat.tar.bz2"
gcc="gcc-$gccVersion"
gccArchive="$gcc.tar.xz"
gdb="gdb-$gdbVersion"
gdbArchive="$gdb.tar.xz"
gmp="gmp-$gmpVersion"
gmpArchive="$gmp.tar.xz"
isl="isl-$islVersion"
islArchive="$isl.tar.xz"
libiconv="libiconv-$libiconvVersion"
libiconvArchive="$libiconv.tar.gz"
mpc="mpc-$mpcVersion"
mpcArchive="$mpc.tar.gz"
mpfr="mpfr-$mpfrVersion"
mpfrArchive="$mpfr.tar.xz"
newlib="newlib-$newlibVersion"
newlibArchive="$newlib.tar.gz"
pythonWin32="python-$pythonVersion"
pythonArchiveWin32="$pythonWin32.msi"
pythonWin64="python-$pythonVersion.amd64"
pythonArchiveWin64="$pythonWin64.msi"
zlib="zlib-$zlibVersion"
zlibArchive="$zlib.tar.gz"

gnumirror="https://ftpmirror.gnu.org"
pkgversion="bleeding-edge-toolchain"
target="arm-none-eabi"
package="$target-$gcc-$(date +'%y%m%d')"
packageArchiveNative="$package.tar.xz"
packageArchiveWin32="$package-win32.7z"
packageArchiveWin64="$package-win64.7z"

uname="$(uname)"
bold="$(tput bold)"
normal="$(tput sgr0)"

if [ "$uname" = "Darwin" ]; then
	nproc="$(sysctl -n hw.ncpu)"
	hostSystem="$(uname -sm)"
else
	nproc="$(nproc)"
	hostSystem="$(uname -mo)"
fi

enableWin32="n"
enableWin64="n"
keepBuildFolders="n"
resume="n"
quiet="n"
buildDocumentation="y"
skipGdb="n"
skipLibc="n"
skipNanoLibraries="n"
while [ ${#} -gt 0 ]; do
	case ${1} in
		--enable-win32)
			enableWin32="y"
			;;
		--enable-win64)
			enableWin64="y"
			;;
		--keep-build-folders)
			keepBuildFolders="y"
			;;
		--resume)
			resume="y"
			;;
		--quiet)
			quiet="y"
			;;
		--skip-documentation)
			buildDocumentation="n"
			;;
		--skip-gdb)
			skipGdb="y"
			;;
		--skip-libc)
			skipLibc="y"
			;;
		--skip-nano-libraries)
			skipNanoLibraries="y"
			;;
		*)
			printf "Usage: $0\n" >&2
			printf "\t\t[--enable-win32] [--enable-win64] [--keep-build-folders] [--quiet] [--resume]\n" >&2
			printf "\t\t[--skip-documentation] [--skip-gdb] [--skip-libc] [--skip-nano-libraries]\n" >&2
			exit 1
			;;
	esac
	shift
done

documentationTypes=""
if [ "$buildDocumentation" = "y" ]; then
	documentationTypes="html pdf"
fi

quietConfigureOptions=""
if [ "$quiet" = "y" ]; then
	quietConfigureOptions="--quiet --enable-silent-rules"
	export MAKEFLAGS="--quiet"
	export GNUMAKEFLAGS="--quiet"
fi

BASE_CPPFLAGS="-pipe"
BASE_LDFLAGS=
BASE_CFLAGS_FOR_TARGET="-pipe -ffunction-sections -fdata-sections"
BASE_CXXFLAGS_FOR_TARGET="-pipe -ffunction-sections -fdata-sections -fno-exceptions"

deleteDir() {
	if [ -d "${1}" ]; then
		rm -rf "${1:?}"
	fi
}

msgA() {
	echo "$bold********** $1$normal"
}

msgB() {
	echo "$bold----------  $1$normal"
}

buildZlib() (
	buildFolder="${1}"
	bannerPrefix="${2}"
	makeOptions="${3}"
	makeInstallOptions="${4}"
	tagFileBase="$top/$buildFolder/zlib"
	msgA "$bannerPrefix$zlib"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$zlib"
		cp -R "$sources/$zlib" "$buildFolder"
		cd "$buildFolder/$zlib"
		export CPPFLAGS="${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$zlib configure"
		./configure --static --prefix="$top/$buildFolder/$prerequisites/$zlib"
		msgB "$bannerPrefix$zlib make"
		eval "make $makeOptions -j$nproc"
		msgB "$bannerPrefix$zlib make install"
		eval "make $makeInstallOptions install"
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$zlib remove build folder"
			deleteDir "$buildFolder/$zlib"
		fi
	fi
)

buildGmp() (
	buildFolder="${1}"
	bannerPrefix="${2}"
	configureOptions="${3}"
	tagFileBase="$top/$buildFolder/gmp"
	msgA "$bannerPrefix$gmp"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$gmp"
		mkdir -p "$buildFolder/$gmp"
		cd "$buildFolder/$gmp"
		export CPPFLAGS="${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$gmp configure"
		eval "$top/$sources/$gmp/configure \
			$quietConfigureOptions \
			$configureOptions \
			--prefix=$top/$buildFolder/$prerequisites/$gmp \
			--enable-cxx \
			--disable-shared \
			--disable-nls"
		msgB "$bannerPrefix$gmp make"
		make -j"$nproc"
		msgB "$bannerPrefix$gmp make install"
		make install
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$gmp remove build folder"
			deleteDir "$buildFolder/$gmp"
		fi
	fi
)

buildMpfr() (
	buildFolder="${1}"
	bannerPrefix="${2}"
	configureOptions="${3}"
	tagFileBase="$top/$buildFolder/mpfr"
	msgA "$bannerPrefix$mpfr"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$mpfr"
		mkdir -p "$buildFolder/$mpfr"
		cd "$buildFolder/$mpfr"
		export CPPFLAGS="${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$mpfr configure"
		eval "$top/$sources/$mpfr/configure \
			$quietConfigureOptions \
			$configureOptions \
			--prefix=$top/$buildFolder/$prerequisites/$mpfr \
			--disable-shared \
			--disable-nls \
			--with-gmp=$top/$buildFolder/$prerequisites/$gmp"
		msgB "$bannerPrefix$mpfr make"
		make -j"$nproc"
		msgB "$bannerPrefix$mpfr make install"
		make install
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$mpfr remove build folder"
			deleteDir "$buildFolder/$mpfr"
		fi
	fi
)


buildMpc() (
	buildFolder="${1}"
	bannerPrefix="${2}"
	configureOptions="${3}"
	tagFileBase="$top/$buildFolder/mpc"
	msgA "$bannerPrefix$mpc"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$mpc"
		mkdir -p "$buildFolder/$mpc"
		cd "$buildFolder/$mpc"
		export CPPFLAGS="${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$mpc configure"
		eval "$top/$sources/$mpc/configure \
			$quietConfigureOptions \
			$configureOptions \
			--prefix=$top/$buildFolder/$prerequisites/$mpc \
			--disable-shared \
			--disable-nls \
			--with-gmp=$top/$buildFolder/$prerequisites/$gmp \
			--with-mpfr=$top/$buildFolder/$prerequisites/$mpfr"
		msgB "$bannerPrefix$mpc make"
		make -j"$nproc"
		msgB "$bannerPrefix$mpc make install"
		make install
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$mpc remove build folder"
			deleteDir "$buildFolder/$mpc"
		fi
	fi
)


buildIsl() (
	buildFolder="${1}"
	bannerPrefix="${2}"
	configureOptions="${3}"
	tagFileBase="$top/$buildFolder/isl"
	msgA "$bannerPrefix$isl"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$isl"
		mkdir -p "$buildFolder/$isl"
		cd "$buildFolder/$isl"
		export CPPFLAGS="${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$isl configure"
		eval "$top/$sources/$isl/configure \
			$quietConfigureOptions \
			$configureOptions \
			--prefix=$top/$buildFolder/$prerequisites/$isl \
			--disable-shared \
			--disable-nls \
			--with-gmp-prefix=$top/$buildFolder/$prerequisites/$gmp"
		msgB "$bannerPrefix$isl make"
		make -j"$nproc"
		msgB "$bannerPrefix$isl make install"
		make install
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$isl remove build folder"
			deleteDir "$buildFolder/$isl"
		fi
	fi
)

buildExpat() (
	buildFolder="${1}"
	bannerPrefix="${2}"
	configureOptions="${3}"
	tagFileBase="$top/$buildFolder/expat"
	msgA "$bannerPrefix$expat"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$expat"
		mkdir -p "$buildFolder/$expat"
		cd "$buildFolder/$expat"
		export CPPFLAGS="${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$expat configure"
		eval "$top/$sources/$expat/configure \
			$quietConfigureOptions \
			$configureOptions \
			--prefix=$top/$buildFolder/$prerequisites/$expat \
			--disable-shared \
			--disable-nls"
		msgB "$bannerPrefix$expat make"
		make -j"$nproc"
		msgB "$bannerPrefix$expat make install"
		make install
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$expat remove build folder"
			deleteDir "$buildFolder/$expat"
		fi
	fi
)

buildBinutils() (
	buildFolder="${1}"
	installFolder="${2}"
	bannerPrefix="${3}"
	configureOptions="${4}"
	documentations="${5}"
	tagFileBase="$top/$buildFolder/binutils"
	msgA "$bannerPrefix$binutils"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$binutils"
		mkdir -p "$buildFolder/$binutils"
		cd "$buildFolder/$binutils"
		export CPPFLAGS="-I$top/$buildFolder/$prerequisites/$zlib/include ${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="-L$top/$buildFolder/$prerequisites/$zlib/lib ${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$binutils configure"
		eval "$top/$sources/$binutils/configure \
			$quietConfigureOptions \
			$configureOptions \
			--target=$target \
			--prefix=$top/$installFolder \
			--docdir=$top/$installFolder/share/doc \
			--disable-nls \
			--enable-interwork \
			--enable-multilib \
			--enable-plugins \
			--with-system-zlib \
			\"--with-pkgversion=$pkgversion\""
		msgB "$bannerPrefix$binutils make"
		make -j"$nproc"
		msgB "$bannerPrefix$binutils make install"
		make install
		for documentation in $documentations; do
			msgB "$bannerPrefix$binutils make install-$documentation"
			make install-"$documentation"
		done
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$binutils remove build folder"
			deleteDir "$buildFolder/$binutils"
		fi
	fi
)

buildGcc() (
	buildFolder="${1}"
	installFolder="${2}"
	bannerPrefix="${3}"
	configureOptions="${4}"
	tagFileBase="$top/$buildFolder/gcc"
	msgA "$bannerPrefix$gcc"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$gcc"
		mkdir -p "$buildFolder/$gcc"
		cd "$buildFolder/$gcc"
		export CPPFLAGS="-I$top/$buildFolder/$prerequisites/$zlib/include ${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="-L$top/$buildFolder/$prerequisites/$zlib/lib ${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$gcc configure"
		eval "$top/$sources/$gcc/configure \
			$quietConfigureOptions \
			$configureOptions \
			$libcConfigureOption \
			--target=$target \
			--prefix=$top/$installFolder \
			--libexecdir=$top/$installFolder/lib \
			--disable-decimal-float \
			--disable-libffi \
			--disable-libgomp \
			--disable-libmudflap \
			--disable-libquadmath \
			--disable-libssp \
			--disable-libstdcxx-pch \
			--disable-nls \
			--disable-shared \
			--disable-threads \
			--disable-tls \
			--with-newlib \
			--with-gnu-as \
			--with-gnu-ld \
			--with-sysroot=$top/$installFolder/$target \
			--with-system-zlib \
			--with-gmp=$top/$buildFolder/$prerequisites/$gmp \
			--with-mpfr=$top/$buildFolder/$prerequisites/$mpfr \
			--with-mpc=$top/$buildFolder/$prerequisites/$mpc \
			--with-isl=$top/$buildFolder/$prerequisites/$isl \
			\"--with-pkgversion=$pkgversion\" \
			--with-multilib-list=rmprofile"
		msgB "$bannerPrefix$gcc make all-gcc"
		make -j"$nproc" all-gcc
		msgB "$bannerPrefix$gcc make install-gcc"
		make install-gcc
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$gcc remove build folder"
			deleteDir "$buildFolder/$gcc"
		fi
	fi
)

buildNewlib() (
	suffix="${1}"
	optimization="${2}"
	configureOptions="${3}"
	documentations="${4}"
	tagFileBase="$top/$buildNative/newlib$suffix"
	msgA "$newlib$suffix"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildNative/$newlib$suffix"
		mkdir -p "$buildNative/$newlib$suffix"
		cd "$buildNative/$newlib$suffix"
		export CPPFLAGS="${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="${BASE_LDFLAGS-} ${LDFLAGS-}"
		export PATH="$top/$installNative/bin:${PATH-}"
		export CFLAGS_FOR_TARGET="-g $optimization ${BASE_CFLAGS_FOR_TARGET-} ${CFLAGS_FOR_TARGET-}"
		msgB "$newlib$suffix configure"
		eval "$top/$sources/$newlib/configure \
			$quietConfigureOptions \
			$configureOptions \
			--target=$target \
			--disable-newlib-supplied-syscalls \
			--enable-newlib-reent-small \
			--disable-newlib-fvwrite-in-streamio \
			--disable-newlib-fseek-optimization \
			--disable-newlib-wide-orient \
			--disable-newlib-unbuf-stream-opt \
			--enable-newlib-global-atexit \
			--enable-newlib-retargetable-locking \
			--enable-newlib-global-stdio-streams \
			--disable-nls"
		msgB "$newlib$suffix make"
		make -j"$nproc"
		msgB "$newlib$suffix make install"
		make install
		for documentation in $documentations; do
			cd "$target"/newlib/libc
			msgB "$newlib$suffix libc make install-$documentation"
			make install-"$documentation"
			cd ../../..
			cd "$target"/newlib/libm
			msgB "$newlib$suffix libm make install-$documentation"
			make install-"$documentation"
			cd ../../..
		done
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$newlib$suffix remove build folder"
			deleteDir "$buildNative/$newlib$suffix"
		fi
	fi
)

buildGccFinal() (
	suffix="${1}"
	optimization="${2}"
	installFolder="${3}"
	documentations="${4}"
	tagFileBase="$top/$buildNative/gcc$suffix"
	msgA "$gcc$suffix"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildNative/$gcc$suffix"
		mkdir -p "$buildNative/$gcc$suffix"
		cd "$buildNative/$gcc$suffix"
		export CPPFLAGS="-I$top/$buildNative/$prerequisites/$zlib/include ${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="-L$top/$buildNative/$prerequisites/$zlib/lib ${BASE_LDFLAGS-} ${LDFLAGS-}"
		export CFLAGS_FOR_TARGET="-g $optimization ${BASE_CFLAGS_FOR_TARGET-} ${CFLAGS_FOR_TARGET-}"
		export CXXFLAGS_FOR_TARGET="-g $optimization ${BASE_CXXFLAGS_FOR_TARGET-} ${CXXFLAGS_FOR_TARGET-}"
		msgB "$gcc$suffix configure"
		"$top/$sources/$gcc"/configure \
			$quietConfigureOptions \
			"$libcConfigureOption" \
			--target="$target" \
			--prefix="$top/$installFolder" \
			--docdir="$top/$installFolder"/share/doc \
			--libexecdir="$top/$installFolder"/lib \
			--enable-languages=c,c++ \
			--disable-libstdcxx-verbose \
			--enable-plugins \
			--disable-decimal-float \
			--disable-libffi \
			--disable-libgomp \
			--disable-libmudflap \
			--disable-libquadmath \
			--disable-libssp \
			--disable-libstdcxx-pch \
			--disable-nls \
			--disable-shared \
			--disable-threads \
			--disable-tls \
			--with-gnu-as \
			--with-gnu-ld \
			--with-newlib \
			--with-headers=yes \
			--with-sysroot="$top/$installFolder/$target" \
			--with-system-zlib \
			--with-gmp="$top/$buildNative/$prerequisites/$gmp" \
			--with-mpfr="$top/$buildNative/$prerequisites/$mpfr" \
			--with-mpc="$top/$buildNative/$prerequisites/$mpc" \
			--with-isl="$top/$buildNative/$prerequisites/$isl" \
			--with-pkgversion="$pkgversion" \
			--with-multilib-list=rmprofile
		msgB "$gcc$suffix make"
		make -j"$nproc" INHIBIT_LIBC_CFLAGS="-DUSE_TM_CLONE_REGISTRY=0"
		msgB "$gcc$suffix make install"
		make install
		for documentation in $documentations; do
			msgB "$gcc$suffix make install-$documentation"
			make install-"$documentation"
		done
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$gcc$suffix remove build folder"
			deleteDir "$buildNative/$gcc$suffix"
		fi
	fi
)

copyNanoLibraries() (
	source="${1}"
	destination="${2}"
	msgA "\"nano\" libraries copy"
	multilibs="$("$destination/bin/$target"-gcc -print-multi-lib)"
	sourcePrefix="$source/$target/lib"
	destinationPrefix="$destination/$target/lib"
	for multilib in $multilibs; do
		multilib="${multilib%%;*}"
		sourceDirectory="$sourcePrefix/$multilib"
		destinationDirectory="$destinationPrefix/$multilib"
		mkdir -p "$destinationDirectory"
		cp "$sourceDirectory/libc.a" "$destinationDirectory/libc_nano.a"
		cp "$sourceDirectory/libg.a" "$destinationDirectory/libg_nano.a"
		cp "$sourceDirectory/librdimon.a" "$destinationDirectory/librdimon_nano.a"
		cp "$sourceDirectory/libstdc++.a" "$destinationDirectory/libstdc++_nano.a"
		cp "$sourceDirectory/libsupc++.a" "$destinationDirectory/libsupc++_nano.a"
	done

	mkdir -p "$destination/$target/include/newlib-nano"
	cp "$source/$target/include/newlib.h" "$destination/$target/include/newlib-nano"

	if [ "$keepBuildFolders" = "n" ]; then
		msgB "\"nano\" libraries remove install folder"
		deleteDir "$top/$buildNative/$nanoLibraries"
	fi
)

buildGdb() (
	buildFolder="${1}"
	installFolder="${2}"
	bannerPrefix="${3}"
	configureOptions="${4}"
	documentations="${5}"
	tagFileBase="$top/$buildFolder/gdb-py"
	case $configureOptions in
		*"--with-python=no"*)
			tagFileBase="$top/$buildFolder/gdb"
			;;
	esac
	msgA "$bannerPrefix$gdb"
	if [ ! -f "${tagFileBase}_built" ]; then
		deleteDir "$buildFolder/$gdb"
		mkdir -p "$buildFolder/$gdb"
		cd "$buildFolder/$gdb"
		export CPPFLAGS="-I$top/$buildFolder/$prerequisites/$zlib/include ${BASE_CPPFLAGS-} ${CPPFLAGS-}"
		export LDFLAGS="-L$top/$buildFolder/$prerequisites/$zlib/lib ${BASE_LDFLAGS-} ${LDFLAGS-}"
		msgB "$bannerPrefix$gdb configure"
		eval "$top/$sources/$gdb/configure \
			$quietConfigureOptions \
			$configureOptions \
			--target=$target \
			--prefix=$top/$installFolder \
			--docdir=$top/$installFolder/share/doc \
			--disable-nls \
			--disable-sim \
			--with-lzma=no \
			--with-guile=no \
			--with-system-gdbinit=$top/$installFolder/$target/lib/gdbinit \
			--with-system-zlib \
			--with-expat=yes \
			--with-libexpat-prefix=$top/$buildFolder/$prerequisites/$expat \
			--with-mpfr=yes \
			--with-libmpfr-prefix=$top/$buildFolder/$prerequisites/$mpfr \
			\"--with-gdb-datadir='\\\${prefix}'/$target/share/gdb\" \
			\"--with-pkgversion=$pkgversion\""
		msgB "$bannerPrefix$gdb make"
		make -j"$nproc"
		msgB "$bannerPrefix$gdb make install"
		make install
		for documentation in $documentations; do
			msgB "$bannerPrefix$gdb make install-$documentation"
			make install-"$documentation"
		done
		touch "${tagFileBase}_built"
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$gdb remove build folder"
			deleteDir "$buildFolder/$gdb"
		fi
	fi
)

postCleanup() (
	installFolder="${1}"
	bannerPrefix="${2}"
	hostSystem="${3}"
	extraComponents="${4}"
	if [ "$uname" = "Darwin" ]; then
		buildSystem="$(uname -srvm)"
	else
		buildSystem="$(uname -srvmo)"
	fi
	msgA "${bannerPrefix}Post-cleanup"
	deleteDir "$installFolder"/include
	find "$installFolder" -name '*.la' -exec rm -rf {} +
	cat > "$installFolder"/info.txt <<- EOF
	${pkgversion}
	build date:    $(date +'%Y-%m-%d')
	build system:  ${buildSystem}
	host system:   ${hostSystem}
	target system: ${target}
	compiler:      $(${CC-gcc} --version | head -n1)

	Toolchain components:
	- ${gcc}
	- ${newlib}
	- ${binutils}
	- ${gdb}
	$(printf -- "- %s\n- %s\n- %s\n- %s\n- %s\n- %s\n%s" "$expat" "$gmp" "$isl" "$mpc" "$mpfr" "$zlib" "$extraComponents" | sort)

	This package and info about it can be found on Freddie Chopin's website:
	http://www.freddiechopin.info/
	EOF
	cp "${0}" "$installFolder"
)

if [ "$resume" = "y" ]; then
	msgA "Resuming last build"
else
	msgA "Cleanup"
	deleteDir "$buildNative"
	deleteDir "$installNative"
	mkdir -p "$buildNative"
	mkdir -p "$installNative"
	deleteDir "$buildWin32"
	deleteDir "$installWin32"
	if [ "$enableWin32" = "y" ]; then
		mkdir -p "$buildWin32"
		mkdir -p "$installWin32"
	fi
	deleteDir "$buildWin64"
	deleteDir "$installWin64"
	if [ "$enableWin64" = "y" ]; then
		mkdir -p "$buildWin64"
		mkdir -p "$installWin64"
	fi
	mkdir -p "$sources"
	find "$sources" -mindepth 1 -maxdepth 1 -type f ! -name "$binutilsArchive" \
		! -name "$expatArchive" \
		! -name "$gccArchive" \
		! -name "$gdbArchive" \
		! -name "$gmpArchive" \
		! -name "$islArchive" \
		! -name "$libiconvArchive" \
		! -name "$mpcArchive" \
		! -name "$mpfrArchive" \
		! -name "$newlibArchive" \
		! -name "$pythonArchiveWin32" \
		! -name "$pythonArchiveWin64" \
		! -name "$zlibArchive" \
		-exec rm -rf {} +
	find "$sources" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
fi

msgA "Download"
mkdir -p "$sources"
cd "$sources"
download() {
	ret=0
	if [ ! -f "${1}_downloaded" ]; then
		msgB "Downloading ${1}"
		curl -L -o "${1}" -C - --connect-timeout 30 -Y 1024 -y 30 "${2}" || ret=$?
		if [ "$ret" -eq 33 ]; then
			echo 'This happens if the file is complete, continuing...'
		elif [ "$ret" -ne 0 ]; then
			exit "$ret"
		fi
		touch "${1}_downloaded"
	fi
}
download "$binutilsArchive" "$gnumirror/binutils/$binutilsArchive"
download "$expatArchive" https://github.com/libexpat/libexpat/releases/download/"$(echo "R_$expatVersion" | sed 's/\./_/g')/$expatArchive"
if [ "${gccVersion#*-}" = "$gccVersion" ]; then
	download "$gccArchive" "$gnumirror/gcc/$gcc/$gccArchive"
else
	download "$gccArchive" https://gcc.gnu.org/pub/gcc/snapshots/"$gccVersion/$gccArchive"
fi
if [ "$skipGdb" = "n" ]; then
	download "$gdbArchive" "$gnumirror/gdb/$gdbArchive"
fi
download "$gmpArchive" "$gnumirror/gmp/$gmpArchive"
download "$islArchive" http://isl.gforge.inria.fr/"$islArchive"
if [ "$enableWin32" = "y" ] || [ "$enableWin64" = "y" ]; then
	download "$libiconvArchive" https://ftp.gnu.org/pub/gnu/libiconv/"$libiconvArchive"
fi
download "$mpcArchive" "$gnumirror/mpc/$mpcArchive"
download "$mpfrArchive" "$gnumirror/mpfr/$mpfrArchive"
if [ "$skipLibc" = "n" ]; then
	download "$newlibArchive" https://sourceware.org/pub/newlib/"$newlibArchive"
fi
if [ "$enableWin32" = "y" ]; then
	download "$pythonArchiveWin32" https://www.python.org/ftp/python/"$pythonVersion/$pythonArchiveWin32"
fi
if [ "$enableWin64" = "y" ]; then
	download "$pythonArchiveWin64" https://www.python.org/ftp/python/"$pythonVersion/$pythonArchiveWin64"
fi
download "$zlibArchive" https://www.zlib.net/fossils/"$zlibArchive"
cd "$top"

msgA "Extract"
cd "$sources"
extract() {
	if [ ! -f "${1}_extracted" ]; then
		msgB "Extracting ${1}"
		tar -xf "${1}"
		touch "${1}_extracted"
	fi
}
extract "$binutilsArchive"
extract "$expatArchive"
extract "$gccArchive"
if [ "$skipGdb" = "n" ]; then
	extract "$gdbArchive"
fi
extract "$gmpArchive"
extract "$islArchive"
if [ "$enableWin32" = "y" ] || [ "$enableWin64" = "y" ]; then
	extract "$libiconvArchive"
fi
extract "$mpcArchive"
extract "$mpfrArchive"
if [ "$skipLibc" = "n" ]; then
	extract "$newlibArchive"
fi
if [ ! -f "${pythonArchiveWin32}_extracted" ] && [ "$enableWin32" = "y" ]; then
	msgB "Extracting $pythonArchiveWin32"
	7za x "$pythonArchiveWin32" -o"$pythonWin32"
	touch "${pythonArchiveWin32}_extracted"
fi
if [ ! -f "${pythonArchiveWin64}_extracted" ] && [ "$enableWin64" = "y" ]; then
	msgB "Extracting $pythonArchiveWin64"
	7za x "$pythonArchiveWin64" -o"$pythonWin64"
	touch "${pythonArchiveWin64}_extracted"
fi
extract "$zlibArchive"
cd "$top"

hostTriplet=$("$sources/$gcc"/config.guess)

buildZlib "$buildNative" "" "" ""

buildGmp "$buildNative" "" "--build=$hostTriplet --host=$hostTriplet"

buildMpfr "$buildNative" "" "--build=$hostTriplet --host=$hostTriplet"

buildMpc "$buildNative" "" "--build=$hostTriplet --host=$hostTriplet"

buildIsl "$buildNative" "" "--build=$hostTriplet --host=$hostTriplet"

buildExpat "$buildNative" "" "--build=$hostTriplet --host=$hostTriplet"

buildBinutils "$buildNative" "$installNative" "" "--build=$hostTriplet --host=$hostTriplet" "$documentationTypes"

buildGcc "$buildNative" "$installNative" "" "--enable-languages=c --without-headers"

if [ "$skipNanoLibraries" = "n" ] && [ "$skipLibc" = "n" ]; then
	(
	export PATH="$top/$installNative/bin:${PATH-}"

	buildNewlib \
		"-nano" \
		"-Os" \
		"--prefix=$top/$buildNative/$nanoLibraries \
			--enable-newlib-nano-malloc \
			--enable-lite-exit \
			--enable-newlib-nano-formatted-io" \
		""

	buildGccFinal "-nano" "-Os" "$buildNative/$nanoLibraries" ""
	)

	if [ -d "$top/$buildNative/$nanoLibraries" ]; then
		copyNanoLibraries "$top/$buildNative/$nanoLibraries" "$top/$installNative"
	fi
fi

if [ "$skipLibc" = "n" ]; then
	buildNewlib \
		"" \
		"-O2" \
		"--prefix=$top/$installNative \
			--docdir=$top/$installNative/share/doc \
			--enable-newlib-io-c99-formats \
			--enable-newlib-io-long-long \
			--disable-newlib-atexit-dynamic-alloc" \
		"$documentationTypes"
	buildGccFinal "-final" "-O2" "$installNative" "$documentationTypes"
fi

if [ "$skipGdb" = "n" ]; then
	buildGdb \
		"$buildNative" \
		"$installNative" \
		"" \
		"--build=$hostTriplet --host=$hostTriplet --with-python=yes" \
		"$documentationTypes"
fi

find "$installNative" -type f -exec chmod a+w {} +
postCleanup "$installNative" "" "$hostSystem" ""
if [ "$uname" = "Darwin" ]; then
	find "$installNative" -type f -perm +111 -exec strip -ur {} \; || true
else
	find "$installNative" -type f -executable -exec strip {} \; || true
fi
find "$installNative" -type f -exec chmod a-w {} +
if [ "$buildDocumentation" = "y" ]; then
	find "$installNative"/share/doc -mindepth 2 -name '*.pdf' -exec mv {} "$installNative"/share/doc \;
fi

msgA "Package"
rm -rf "$package"
ln -s "$installNative" "$package"
rm -rf "$packageArchiveNative"
if [ "$uname" = "Darwin" ]; then
	XZ_OPT=${XZ_OPT-"-9e -v"} tar -cJf "$packageArchiveNative" "$package"/*
else
	XZ_OPT=${XZ_OPT-"-9e -v"} tar -cJf "$packageArchiveNative" --mtime='@0' --numeric-owner --group=0 --owner=0 "$package"/*
fi
rm -rf "$package"

if [ "$enableWin32" = "y" ] || [ "$enableWin64" = "y" ]; then

buildMingw() (
	triplet="${1}"
	flags="${2}"
	buildFolder="${3}"
	installFolder="${4}"
	pythonFolder="${5}"
	bannerPrefix="${6}"
	packageArchive="${7}"

	export AR="$triplet-ar"
	export AS="$triplet-as"
	export CC="$triplet-gcc"
	export CC_FOR_BUILD="gcc"
	export CFLAGS="$flags ${CFLAGS-}"
	export CXX="$triplet-g++"
	export CXXFLAGS="$flags ${CXXFLAGS-}"
	export NM="$triplet-nm"
	export OBJDUMP="$triplet-objdump"
	export PATH="$top/$installNative/bin:${PATH-}"
	export RANLIB="$triplet-ranlib"
	export RC="$triplet-windres"
	export STRIP="$triplet-strip"
	export WINDRES="$triplet-windres"

	mkdir -p "$installFolder/$target"
	cp -R "$installNative/$target"/include "$installFolder/$target"/include
	cp -R "$installNative/$target"/lib "$installFolder/$target"/lib
	mkdir -p "$installFolder"/lib
	cp -R "$installNative"/lib/gcc "$installFolder"/lib/gcc
	mkdir -p "$installFolder"/share
	if [ "$buildDocumentation" = "y" ]; then
		cp -R "$installNative"/share/doc "$installFolder"/share/doc
	fi
	cp -R "$installNative"/share/gcc-* "$installFolder"/share/

	(
		msgA "$bannerPrefix$libiconv"
		mkdir -p "$buildFolder/$libiconv"
		cd "$buildFolder/$libiconv"
		msgB "$bannerPrefix$libiconv configure"
		"$top/$sources/$libiconv"/configure \
			"$quietConfigureOptions" \
			--build="$hostTriplet" \
			--host="$triplet" \
			--prefix="$top/$buildFolder/$prerequisites/$libiconv" \
			--disable-shared \
			--disable-nls
		msgB "$bannerPrefix$libiconv make"
		make -j"$nproc"
		msgB "$bannerPrefix$libiconv make install"
		make install
		cd "$top"
		if [ "$keepBuildFolders" = "n" ]; then
			msgB "$bannerPrefix$libiconv remove build folder"
			deleteDir "$top/$buildFolder/$libiconv"
		fi
	)

	buildZlib \
		"$buildFolder" \
		"$bannerPrefix" \
		"-f win32/Makefile.gcc PREFIX=\"$triplet-\" CFLAGS=\"$CFLAGS\"" \
		"-f win32/Makefile.gcc \
			BINARY_PATH=\"$top/$buildFolder/$prerequisites/$zlib/bin\" \
			INCLUDE_PATH=\"$top/$buildFolder/$prerequisites/$zlib/include\" \
			LIBRARY_PATH=\"$top/$buildFolder/$prerequisites/$zlib/lib\""

	buildGmp \
		"$buildFolder" \
		"$bannerPrefix" \
		"--build=$hostTriplet --host=$triplet"

	buildMpfr \
		"$buildFolder" \
		"$bannerPrefix" \
		"--build=$hostTriplet --host=$triplet"

	buildMpc \
		"$buildFolder" \
		"$bannerPrefix" \
		"--build=$hostTriplet --host=$triplet"

	buildIsl \
		"$buildFolder" \
		"$bannerPrefix" \
		"--build=$hostTriplet --host=$triplet"

	buildExpat \
		"$buildFolder" \
		"$bannerPrefix" \
		"--build=$hostTriplet --host=$triplet"

	buildBinutils \
		"$buildFolder" \
		"$installFolder" \
		"$bannerPrefix" \
		"--build=$hostTriplet --host=$triplet" \
		""

	buildGcc \
		"$buildFolder" \
		"$installFolder" \
		"$bannerPrefix" \
		"--build=$hostTriplet --host=$triplet \
			--enable-languages=c,c++ \
			--with-headers=yes \
			--with-libiconv-prefix=$top/$buildFolder/$prerequisites/$libiconv"

	cat > "$buildFolder"/python.sh <<- EOF
	#!/bin/sh
	shift
	while [ \${#} -gt 0 ]; do
		case \${1} in
			--prefix|--exec-prefix)
				echo "${top}/${sources}/${pythonFolder}"
				;;
			--includes)
				echo "-D_hypot=hypot -I${top}/${sources}/${pythonFolder}"
				;;
			--ldflags)
				echo "-L${top}/${sources}/${pythonFolder} -lpython$(echo "${pythonVersion}" | sed -n 's/^\([^.]\{1,\}\)\.\([^.]\{1,\}\).*$/\1\2/p')"
				;;
		esac
		shift
	done
	EOF
	chmod +x "$buildFolder"/python.sh

	if [ "$skipGdb" = "n" ]; then
		buildGdb \
			"$buildFolder" \
			"$installFolder" \
			"$bannerPrefix" \
			"--build=$hostTriplet --host=$triplet \
				--with-python=$top/$buildFolder/python.sh \
				--program-prefix=$target- \
				--program-suffix=-py \
				--with-libiconv-prefix=$top/$buildFolder/$prerequisites/$libiconv" \
			""
		if [ "$keepBuildFolders" = "y" ]; then
			mv "$buildFolder/$gdb" "$buildFolder/$gdb"-py
		fi

		buildGdb \
			"$buildFolder" \
			"$installFolder" \
			"$bannerPrefix" \
			"--build=$hostTriplet --host=$triplet \
				--with-python=no \
				--with-libiconv-prefix=$top/$buildFolder/$prerequisites/$libiconv" \
			""
	fi

	postCleanup "$installFolder" "$bannerPrefix" "$triplet" "- $libiconv\n- python-$pythonVersion\n"
	deleteDir "$installFolder/lib/gcc/$target/$gccVersion"/plugin
	deleteDir "$installFolder"/share/info
	deleteDir "$installFolder"/share/man
	find "$installFolder" -executable ! -type d ! -name '*.exe' ! -name '*.dll' ! -name '*.sh' -exec rm -f {} +
	dlls="$(find "$installFolder"/ -name '*.exe' -exec "$triplet"-objdump -p {} \; | sed -ne "s/^.*DLL Name: \(.*\)$/\1/p" | sort | uniq)"
	for dll in $dlls; do
		cp /usr/"$triplet/bin/$dll" "$installFolder"/bin/ || true
	done
	find "$installFolder" -name '*.exe' -exec "$STRIP" {} \;
	find "$installFolder" -name '*.dll' -exec "$STRIP" --strip-unneeded {} \;
	sed -i 's/$/\r/' "$installFolder"/info.txt

	msgA "${bannerPrefix}Package"
	rm -rf "$package"
	ln -s "$installFolder" "$package"
	rm -rf "$packageArchive"
	7za a -l -mx=9 "$packageArchive" "$package"
	rm -rf "$package"
)

if [ "$enableWin32" = "y" ]; then
	buildMingw \
		"i686-w64-mingw32" \
		"-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions --param=ssp-buffer-size=4" \
		"$buildWin32" \
		"$installWin32" \
		"$pythonWin32" \
		"Win32: " \
		"$packageArchiveWin32"
fi

if [ "$enableWin64" = "y" ]; then
	buildMingw \
		"x86_64-w64-mingw32" \
		"-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions --param=ssp-buffer-size=4" \
		"$buildWin64" \
		"$installWin64" \
		"$pythonWin64" \
		"Win64: " \
		"$packageArchiveWin64"
fi

fi	# if [ "${enableWin32}" = "y" ] || [ "${enableWin64}" = "y" ]; then

msgA "Done"
