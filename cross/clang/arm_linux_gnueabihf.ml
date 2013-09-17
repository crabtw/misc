let home = Sys.getenv "HOME"
let llvm_path = home ^ "/src/llvm-svn/b/Release+Asserts/bin"
let toolchain_dir = home ^ "/tmp/rpi-tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian"
let toolchain_path = toolchain_dir ^ "/bin"

let cc =
  let cmd = Sys.argv.(0) in
  let len = String.length cmd in
  if len >= 2 && (String.sub cmd (len-2) 2) = "++"
    then "clang++" else "clang"

let settings = [|
  cc;
  "-target"; "arm-linux-gnueabihf";
  "-mcpu=arm1176jzf-s";
  "--sysroot"; toolchain_dir ^ "/arm-linux-gnueabihf/libc";
  "-B" ^ toolchain_dir ^ "/lib/gcc/arm-linux-gnueabihf/4.7.2";
  "-L" ^ toolchain_dir ^ "/lib/gcc/arm-linux-gnueabihf/4.7.2";
  "-L" ^ toolchain_dir ^ "/arm-linux-gnueabihf/lib";
  "-I" ^ toolchain_dir ^ "/arm-linux-gnueabihf/include/c++/4.7.2";
  "-I" ^ toolchain_dir ^ "/arm-linux-gnueabihf/include/c++/4.7.2/arm-linux-gnueabihf";
  (*"-integrated-as";*)
  "-Qunused-arguments";
|]

let args =
  let has_cc1 = Array.fold_left (fun x a -> x || a = "-cc1") false Sys.argv in
  let prefix = if has_cc1 then [| settings.(0) |] else settings in
  let cc_args = Array.sub Sys.argv 1 (Array.length Sys.argv - 1) in
  Array.append prefix cc_args

let prepend_path path =
  let cur = Unix.getenv "PATH" in
  let new_path = path ^ ":" ^ cur in
  Unix.putenv "PATH" new_path

let () =
  let () = prepend_path toolchain_path in
  let () = prepend_path llvm_path in
  Unix.execvp cc args
