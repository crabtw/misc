let home = Sys.getenv "HOME"
let llvm_path = home ^ "/src/llvm-git/b/Release+Asserts/bin"
let toolchain_dir = home ^ "/toolchain/arm-linux-gnueabihf"
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
  "-gcc-toolchain"; toolchain_dir;
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
