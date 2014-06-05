#!/bin/sh

#PLATFORM=clang_linux
#TARGET=asan-arm
#CC=$HOME/bin/arm-linux-gnueabihf-clang

PLATFORM=clang_linux
TARGET=asan-mips
CC=$HOME/bin/mips-linux-gnu-clang

LLVM_SRC=$HOME/src/llvm-git
LLVM_BUILD=$LLVM_SRC/b

RT_SRC=$LLVM_SRC/projects/compiler-rt
RT_BUILD=$LLVM_BUILD/tools/clang/runtime/compiler-rt

CLANG_LIB=$LLVM_BUILD/Release+Asserts/lib/clang/3.5.0/lib/linux

rm -rf $RT_BUILD/$PLATFORM/$TARGET
make -C $RT_SRC \
    VERBOSE=1 \
    ProjSrcRoot=$RT_SRC \
    ProjObjRoot=$RT_BUILD \
    CC=$CC \
    $PLATFORM
yes|cp $RT_BUILD/$PLATFORM/$TARGET/libcompiler_rt.a \
       $CLANG_LIB/libclang_rt.$TARGET.a
