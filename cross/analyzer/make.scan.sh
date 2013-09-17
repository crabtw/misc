#!/bin/sh

TARGET="mips-unknown-linux-uclibc"
TOOLCHAIN_PATH="$HOME/x-tools/$TARGET"

SCAN_BUILD_DIR="$HOME/src/llvm-svn/tools/clang/tools/scan-build"
SCAN_BUILD_CC="$HOME/bin/$TARGET-clang"
SCAN_BUILD_CXX="$HOME/bin/$TARGET-clang++"
SCAN_BUILD_OUT="analysis"
SCAN_BUILD_OPTS="-maxloop 100"

export PATH="$SCAN_BUILD_DIR:$TOOLCHAIN_PATH/bin:$PATH"

scan-build \
    --use-analyzer="$SCAN_BUILD_CC" \
    --use-cc="$SCAN_BUILD_CC" \
    --use-c++="$SCAN_BUILD_CXX" \
    -o "$SCAN_BUILD_OUT" \
    $SCAN_BUILD_OPTS \
    \
    make $*
