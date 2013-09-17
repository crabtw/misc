#!/bin/sh

HOST=x86_64-unknown-linux-gnu

#TARGET=mips-unknown-linux-gnu
#CROSS_TOOL=$HOME/tmp/mips-2013.05/bin
#CXX=mips-linux-gnu-g++
#CXXFLAGS="-shared -fPIC -mips32r2 -msoft-float -mabi=32"
#LLCFLAGS="-march=mips -mcpu=mips32r2 -soft-float -mattr=+mips32r2,+o32 -relocation-model=pic -disable-fp-elim -segmented-stacks"

TARGET=arm-unknown-linux-gnueabihf
CROSS_TOOL=$HOME/tmp/rpi-tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin
CXX=arm-linux-gnueabihf-g++
CXXFLAGS="-shared -fPIC"
LLCFLAGS="-march=arm -mcpu=arm1176jzf-s -float-abi=hard -relocation-model=pic -disable-fp-elim -segmented-stacks -arm-enable-ehabi -arm-enable-ehabi-descriptors"

RUST_SRC=$HOME/src/rust-git
RUST_BUILD=$RUST_SRC/b
RUST_LIB=$RUST_BUILD/$HOST/stage2/lib/rustc
LLVM_TOOL=$RUST_BUILD/llvm/$HOST/Release+Asserts/bin

export PATH=$RUST_BUILD/$HOST/stage2/bin:$CROSS_TOOL:$LLVM_TOOL:$PATH

rustc --target=$TARGET --cfg stage2 --emit-llvm $RUST_SRC/src/libstd/std.rs -o $RUST_BUILD/libstd.bc
llc $LLCFLAGS $RUST_BUILD/libstd.bc -o $RUST_BUILD/libstd.s
$CXX $CXXFLAGS $RUST_BUILD/libstd.s -o $RUST_BUILD/libstd.so -L$RUST_BUILD -lrustrt -pthread -ldl -lrt -lmorestack
yes|cp $RUST_BUILD/libstd.so $RUST_LIB/$TARGET/lib/`find $RUST_LIB/$HOST/lib -name libstd-*.so -exec basename {} \;`
 
rustc --target=$TARGET --cfg stage2 --emit-llvm $RUST_SRC/src/libextra/extra.rs -o $RUST_BUILD/libextra.bc
llc $LLCFLAGS $RUST_BUILD/libextra.bc -o $RUST_BUILD/libextra.s
$CXX $CXXFLAGS $RUST_BUILD/libextra.s -o $RUST_BUILD/libextra.so -L$RUST_BUILD -lstd -lmorestack
yes|cp $RUST_BUILD/libextra.so $RUST_LIB/$TARGET/lib/`find $RUST_LIB/$HOST/lib -name libextra-*.so -exec basename {} \;`
