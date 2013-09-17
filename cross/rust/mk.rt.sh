#!/bin/sh

HOST=x86_64-unknown-linux-gnu

#TARGET=mips-unknown-linux-gnu
#CROSS_TOOL=$HOME/tmp/mips-2013.05/bin
#CXX=mips-linux-gnu-g++
#AR=mips-linux-gnu-ar
#CXXFLAGS="-c -fPIC -mips32r2 -msoft-float -mabi=32"

TARGET=arm-unknown-linux-gnueabihf
CROSS_TOOL=$HOME/tmp/rpi-tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin
CXX=arm-linux-gnueabihf-g++
AR=arm-linux-gnueabihf-ar
CXXFLAGS="-c -fPIC"

ARCH=`echo $TARGET|cut -d - -f 1`
RUST_SRC=$HOME/src/rust-git
RUST_BUILD=$RUST_SRC/b
 
export PATH=$RUST_BUILD/$HOST/stage2/bin:$CROSS_TOOL:$PATH

RT_SRC_ARCH=$RUST_SRC/src/rt/arch/$ARCH
RT_BUILD=$RUST_BUILD/rt/$TARGET/stage2
RT_BUILD_ARCH=$RT_BUILD/arch/$ARCH
 
$CXX $CXXFLAGS $RT_SRC_ARCH/ccall.S -o $RT_BUILD_ARCH/ccall.o
$CXX $CXXFLAGS $RT_SRC_ARCH/_context.S -o $RT_BUILD_ARCH/_context.o
$CXX $CXXFLAGS $RT_SRC_ARCH/record_sp.S -o $RT_BUILD_ARCH/record_sp.o
$CXX $CXXFLAGS $RT_SRC_ARCH/morestack.S -o $RT_BUILD_ARCH/morestack.o
$AR rcs $RUST_BUILD/libmorestack.a $RT_BUILD_ARCH/morestack.o
make -C $RUST_BUILD `echo $RT_BUILD|sed "s,$RUST_BUILD/,,"`/librustrt.so VERBOSE=1 -j4
yes|cp $RT_BUILD/librustrt.so $RUST_BUILD
