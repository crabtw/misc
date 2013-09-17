#!/bin/sh

HOST=x86_64-unknown-linux-gnu

#TARGET=mips-unknown-linux-gnu
#CROSS_TOOL=$HOME/tmp/mips-2013.05/bin
#CXX=mips-linux-gnu-g++
#CXXFLAGS="-fPIC -mips32r2 -msoft-float -mabi=32"
#LLCFLAGS="-march=mips -mcpu=mips32r2 -soft-float -mattr=+mips32r2,+o32 -relocation-model=pic -disable-fp-elim -segmented-stacks"

TARGET=arm-unknown-linux-gnueabihf
CROSS_TOOL=$HOME/tmp/rpi-tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin
CXX=arm-linux-gnueabihf-g++
CXXFLAGS="-fPIC"
LLCFLAGS="-march=arm -mcpu=arm1176jzf-s -float-abi=hard -relocation-model=pic -disable-fp-elim -segmented-stacks -arm-enable-ehabi -arm-enable-ehabi-descriptors"

RUST_SRC=$HOME/src/rust-git
RUST_BUILD=$RUST_SRC/b
LLVM_TOOL=$RUST_BUILD/llvm/$HOST/Release+Asserts/bin

ROOTFS=/mnt/rpi
CP="sudo cp"

export PATH=$RUST_BUILD/$HOST/stage2/bin:$CROSS_TOOL:$LLVM_TOOL:$PATH

#sh rt.sh
#sh lib.sh
#yes|$CP $RUST_BUILD/librustrt.so $RUST_BUILD/libstd.so $RUST_BUILD/libextra.so $ROOTFS/usr/lib/

TEST_SRC=$RUST_BUILD/test.rs
#TEST_SRC="--cfg stage2 --test $RUST_SRC/src/libstd/std.rs"
#TEST_SRC="--cfg stage2 --test $RUST_SRC/src/libextra/extra.rs"

rustc --target=$TARGET --emit-llvm $TEST_SRC -o $RUST_BUILD/test.bc
llc $LLCFLAGS $RUST_BUILD/test.bc -o $RUST_BUILD/test.s
$CXX $CXXFLAGS $RUST_BUILD/test.s -L$RUST_BUILD -lextra -lstd -lrustrt -lpthread -lmorestack -lrt -ldl
yes|$CP $RUST_BUILD/a.out $ROOTFS/root/
