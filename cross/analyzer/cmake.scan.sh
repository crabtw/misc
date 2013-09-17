#!/bin/sh

TARGET="mips-unknown-linux-uclibc"
TOOLCHAIN_PATH="$HOME/x-tools/$TARGET"
SYSROOT="$HOME/sysroot/$TARGET"

SCAN_BUILD_DIR="$HOME/src/llvm-svn/tools/clang/tools/scan-build"
SCAN_BUILD_CC="$HOME/bin/$TARGET-clang"
SCAN_BUILD_CXX="$HOME/bin/$TARGET-clang++"
SCAN_BUILD_OUT="analysis"

export PATH="$SCAN_BUILD_DIR:$TOOLCHAIN_PATH/bin:$PATH"

export CC="$TARGET-gcc"
export CPP="$TARGET-cpp"
export CXX="$TARGET-g++"
export LD="$TARGET-ld"
export AR="$TARGET-ar"
export AS="$TARGET-as"
export STRIP="$TARGET-strip"

export CFLAGS="--sysroot=$SYSROOT $CFLAGS"
export CXXFLAGS="--sysroot=$SYSROOT $CXXFLAGS"
export LDFLAGS="--sysroot=$SYSROOT $LDFLAGS"
export CPPFLAGS="--sysroot=$SYSROOT $CPPFLAGS"

scan-build \
    --use-analyzer="$SCAN_BUILD_CC" \
    --use-cc="$SCAN_BUILD_CC" \
    --use-c++="$SCAN_BUILD_CXX" \
    -o "$SCAN_BUILD_OUT" \
    \
    cmake -DCMAKE_TOOLCHAIN_FILE="$HOME/cmake/cross.cmake" $*
