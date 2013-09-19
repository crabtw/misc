let home = Sys.getenv "HOME"
let llvm_path = home ^ "/src/llvm-svn/b/Release+Asserts/bin"
let toolchain_dir = home ^ "/tmp/mips-2013.05"
let toolchain_path = toolchain_dir ^ "/bin"

let cc =
  let cmd = Sys.argv.(0) in
  let len = String.length cmd in
  if len >= 2 && (String.sub cmd (len-2) 2) = "++"
    then "clang++" else "clang"

let settings = [|
  cc;
  "-target"; "mips-linux-gnu";
  "-msoft-float";
  "-mips32r2";
  "-mabi=32";
  "-fPIC";
  "--sysroot"; toolchain_dir ^ "/mips-linux-gnu/libc";
  "-B" ^ toolchain_dir ^ "/lib/gcc/mips-linux-gnu/4.7.3";
  "-L" ^ toolchain_dir ^ "/lib/gcc/mips-linux-gnu/4.7.3";
  "-I" ^ toolchain_dir ^ "/mips-linux-gnu/include/c++/4.7.3";
  "-I" ^ toolchain_dir ^ "/mips-linux-gnu/include/c++/4.7.3/mips-linux-gnu";
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
