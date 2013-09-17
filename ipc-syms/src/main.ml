open Batteries

type dyn_entry = {
  d_tag : Int32.t;
  d_val : Int32.t;
}

type sym_entry = {
  st_name : string;
  st_value : Int32.t;
  st_size : Int32.t;
  st_info : int;
  st_other : int;
  st_shndx : int;
}

type got_entry = {
  g_off : Int32.t;
  g_addr : Int32.t;
}

type inst = {
  i_addr : Int32.t;
  i_data : string;
  i_inst : Mips32dis.instruction;
}

let dt_mips_local_gptno = Int32.of_string "0x7000000a"
let dt_mips_symtabno = Int32.of_string "0x70000011"
let dt_mips_gotsym = Int32.of_string "0x70000013"
let word_size = Int32.of_int 4
let gp_got_off = Int32.of_int 0x7ff0
let stt_func = 2

let gpr_lst = let open Mips32dis in [|
  R0;  R1;  R2;  R3;  R4;  R5;  R6;  R7;
  R8;  R9;  R10; R11; R12; R13; R14; R15;
  R16; R17; R18; R19; R20; R21; R22; R23;
  R24; R25; R16; R27; R28; R29; R30; R31;
|]

let find_sh_by_name e name =
  List.find (fun s -> s.Elf.sh_name = name) e.Elf.e_sections

let find_sh_by_addr e addr =
  List.find (fun s ->
    let b = Int64.to_int32 s.Elf.sh_addr in
    let e = Int64.to_int32 (Int64.add s.Elf.sh_addr s.Elf.sh_size) in
    s.Elf.sh_type <> Elf.SHT_NULL && b <= addr && addr < e
  ) e.Elf.e_sections

let find_sym_name_by_addr sym addr =
  try
    let sym = List.find (fun s ->
      let b = s.st_value in
      let e = Int32.add s.st_value s.st_size in
      (s.st_info land stt_func) = stt_func && b <= addr && addr < e
    ) sym in
    sym.st_name
  with Not_found -> "?"

let get_c_str ix strarr =
  let buf = Buffer.create 10 in
  let rec loop n =
    if strarr.[n] = '\x00' then
      Buffer.contents buf
    else
      let () = Buffer.add_char buf strarr.[n] in
      loop (n + 1)
  in
  loop ix

let get_c_str_by_addr e addr =
  try
    let sh = find_sh_by_addr e addr in
    let off = Int32.sub addr (Int64.to_int32 sh.Elf.sh_addr) in
    get_c_str (Int32.to_int off) sh.Elf.sh_data
  with Not_found -> "?"

let get_dyn_es e =
  let rec parse_sh data es =
    bitmatch data with
    | { d_tag : 32 : bigendian;
        d_val : 32 : bigendian;
        rest  : -1 : bitstring
      } -> parse_sh rest ({ d_tag = d_tag; d_val = d_val } :: es)
    | { _ } -> es
  in
  let sh = find_sh_by_name e ".dynamic" in
  let bit = Bitstring.bitstring_of_string sh.Elf.sh_data in
  List.rev (parse_sh bit [])

let get_sym_tbl e symtbl strtbl =
  let sym_sh = find_sh_by_name e symtbl in
  let str_sh = find_sh_by_name e strtbl in
  let strdata = str_sh.Elf.sh_data in
  let rec parse_sh data es =
    bitmatch data with
    | { st_name  : 32 : bigendian;
        st_value : 32 : bigendian;
        st_size  : 32 : bigendian;
        st_info  : 8;
        st_other : 8;
        st_shndx : 16;
        rest     : -1 : bitstring
      } ->
        let e = {
          st_name = get_c_str (Int32.to_int st_name) strdata;
          st_value = st_value;
          st_size = st_size;
          st_info = st_info;
          st_other = st_other;
          st_shndx = st_shndx;
        }
        in
        parse_sh rest (e :: es)
    | { _ } -> es
  in
  let bit = Bitstring.bitstring_of_string sym_sh.Elf.sh_data in
  List.rev (parse_sh bit [])

let get_got_es e =
  let rec parse_sh data off es =
    bitmatch data with
    | { addr : 32 : bigendian;
        rest  : -1 : bitstring
      } ->
        let g_off = Int32.sub off gp_got_off in
        parse_sh rest (Int32.add off word_size) ({ g_off = g_off; g_addr = addr } :: es)
    | { _ } -> es
  in
  let sh = find_sh_by_name e ".got" in
  let bit = Bitstring.bitstring_of_string sh.Elf.sh_data in
  List.rev (parse_sh bit Int32.zero [])

let get_gp_off e =
  let dyn_es = get_dyn_es e in

  let local_gotno = List.find (fun de -> de.d_tag = dt_mips_local_gptno) dyn_es in
  let symtabno = List.find (fun de -> de.d_tag = dt_mips_symtabno) dyn_es in
  let gotsym = List.find (fun de -> de.d_tag = dt_mips_gotsym) dyn_es in

  let dyn_syms = List.drop (Int32.to_int gotsym.d_val) (get_sym_tbl e ".dynsym" ".dynstr") in
  let got_es = List.drop (Int32.to_int local_gotno.d_val) (get_got_es e) in
  let dyn_got = List.combine dyn_syms got_es in

  let get_got_off_by_name name =
    try 
      let (_, got) = List.find (fun (d, _) -> d.st_name = name) dyn_got in
      Some got.g_off
    with Not_found -> None
  in
  let ipc_init = get_got_off_by_name "ipc_init" in
  let ipc_call = get_got_off_by_name "ipc_call" in
  let ipc_bind = get_got_off_by_name "ipc_bind" in
  let ipc_raise = get_got_off_by_name "ipc_raise" in
  let ipc_signal = get_got_off_by_name "ipc_signal" in
  (ipc_init, ipc_call, ipc_bind, ipc_raise, ipc_signal)

let disas_sh sh =
  let empty = {
    i_addr = Int32.zero;
    i_data = "";
    i_inst = {
      Mips32dis.opcode = Mips32dis.Invalid;
      Mips32dis.operands = []
    };
  }
  in
  let lst = Dllist.create empty in

  let data = sh.Elf.sh_data in
  let base_addr = Int64.to_int32 sh.Elf.sh_addr in
  let len = String.length data in

  let rec disas ix insts =
    if ix <> len then
      let word = String.create 4 in
      let () = word.[0] <- data.[ix] in
      let () = word.[1] <- data.[ix + 1] in
      let () = word.[2] <- data.[ix + 2] in
      let () = word.[3] <- data.[ix + 3] in
      let inst = Mips32dis.decode word in
      let inst = {
        i_addr = Int32.add base_addr (Int32.of_int ix);
        i_data = word;
        i_inst = inst;
      }
      in
      disas (ix + 4) (Dllist.append insts inst)
    else lst
  in
  Dllist.next (disas 0 lst)

let find_func_call asm sym gp_off proc =
  let open Mips32dis in
  let rec find_jalr cur =
    let inst = Dllist.get cur in
    match inst.i_inst with
    | { opcode = JALR;
        operands = _;
      } ->
      let cur = Dllist.next cur in
      let inst = Dllist.get cur in
      let fname = find_sym_name_by_addr sym inst.i_addr in
      (fname, proc cur)
    | _ -> find_jalr (Dllist.next cur)
  in
  let rec loop cur insts =
    let inst = Dllist.get cur in
    if inst.i_addr <> Int32.zero then
      match inst.i_inst with
      | { opcode = LW;
          operands = [_; Mem_imm (GPR R28, off)]
        } when off = gp_off
        -> loop (Dllist.next cur) ((find_jalr cur) :: insts)
      | _ -> loop (Dllist.next cur) insts
    else insts
  in
  List.rev (loop asm [])

let find_func_arg reg asm =
  let open Mips32dis in
  let rec loop cur reg insts =
    let inst = Dllist.get cur in
    if inst.i_addr <> Int32.zero then
      match inst.i_inst.operands with
      | [Reg r; Imm _] when r = reg ->
        (Dllist.get cur) :: insts
      | [Reg r1; Reg r2]
      | [Reg r1; Mem_imm (r2, _)]
      | [Reg r1; Reg r2; Imm _] when r1 = reg ->
        let insts' = if r2 = GPR R0 then [] else loop (Dllist.prev cur) r2 [] in
        insts' @ ((Dllist.get cur) :: insts)
      | [Reg r1; Reg r2; Reg r3] when r1 = reg ->
        let insts' = if r2 = GPR R0 then [] else loop (Dllist.prev cur) r2 [] in
        let insts'' =  if r3 = GPR R0 then [] else loop (Dllist.prev cur) r3 [] in
        insts'' @ insts' @ ((Dllist.get cur) :: insts)
      | _ -> loop (Dllist.prev cur) reg insts
    else insts
  in
  loop asm reg []

let eval_insts arg_reg insts =
  let open Mips32dis in
  let regs = Hashtbl.create (Array.length gpr_lst) in
  let () = Array.iter (fun r -> Hashtbl.replace regs r Int32.zero) gpr_lst in
  let eval inst =
    match inst.i_inst with
    | { opcode = LUI;
        operands = [Reg (GPR r); Imm i]
      } -> Hashtbl.replace regs r (Int32.shift_left i 16)
    | { opcode = ADDIU;
        operands = [Reg (GPR r1); Reg (GPR r2); Imm i]
      } ->
      let old_val = Hashtbl.find regs r2 in
      let new_val = Int32.add old_val i in
      Hashtbl.replace regs r1 new_val
    | { opcode = ADDU;
        operands = [Reg (GPR r1); Reg (GPR r2); Reg (GPR r3)]
      } ->
      let old1 = Hashtbl.find regs r2 in
      let old2 = Hashtbl.find regs r3 in
      Hashtbl.replace regs r1 (Int32.add old1 old2)
    | _  -> ()
  in
  let () = List.iter eval insts in
  Hashtbl.find regs arg_reg

let get_func_arg call reg getter =
  let arg_insts = find_func_arg (Mips32dis.GPR reg) call in
  let arg_ptr = eval_insts reg arg_insts in
  getter arg_ptr

let get_fmap_str e sym addr =
  let rec loop data es =
    bitmatch data with
    | { name     : 32 : bigendian;
        func     : 32 : bigendian;
        in_type  : 32 : bigendian;
        out_type : 32 : bigendian;
        rest     : -1 : bitstring
      } ->
        if name = Int32.zero then
          es
        else
          let x = (
            get_c_str_by_addr e name,
            find_sym_name_by_addr sym func,
            get_c_str_by_addr e in_type,
            get_c_str_by_addr e out_type
          ) in
          loop rest (x :: es)
    | { _ } -> [("?", "?", "?", "?")]
  in
  try
    if addr = Int32.zero
      then []
    else
      let sh = find_sh_by_addr e addr in
      let off = Int32.sub addr (Int64.to_int32 sh.Elf.sh_addr) in
      let data = Bitstring.bitstring_of_string sh.Elf.sh_data in
      let data = Bitstring.dropbits (Int32.to_int off * 8) data in
      loop data []
  with Not_found -> []

let output exe f =
  let () = Printf.printf "{\"exe\":\"%s\"," exe in
  let () = f exe in
  print_endline "}"

let output_call exe init call =
  let init = List.map (fun (fn, (d, f)) ->
    let fmap = List.map (fun (name, func, _, _) ->
      Printf.sprintf "{\"name\":\"%s\",\"func\":\"%s\"}" name func
    ) f in 
    let fmap = String.concat "," fmap in
    Printf.sprintf "{\"caller\":\"%s\",\"daemon\":\"%s\",\"fmap\":[%s]}" fn d fmap
  ) init in
  let () = Printf.printf "\"init\":[%s]," (String.concat "," init) in

  let call = List.map (fun (fn, (d, f)) ->
    Printf.sprintf "{\"caller\":\"%s\",\"daemon\":\"%s\",\"func\":\"%s\"}" fn d f
  ) call in
  Printf.printf "\"call\":[%s]," (String.concat "," call)

let output_signal exe bind raise_ signal =
  let bind = List.map (fun (fn, s) ->
    Printf.sprintf ("{\"caller\":\"%s\",\"sig\":\"%s\"}") fn s
  ) bind in
  let () = Printf.printf "\"bind\":[%s]," (String.concat "," bind) in

  let raise_ = List.map (fun (fn, s) ->
    Printf.sprintf ("{\"caller\":\"%s\",\"sig\":\"%s\"}") fn s
  ) raise_ in
  let () = Printf.printf "\"raise\":[%s]," (String.concat "," raise_) in

  let signal = List.map (fun (fn, (d, s, f)) ->
    Printf.sprintf ("{\"caller\":\"%s\",\"daemon\":\"%s\",\"sig\":\"%s\",\"func\":\"%s\"}") fn d s f
  ) signal in
  Printf.printf "\"signal\":[%s]" (String.concat "," signal)

let proc_elf e exe =
  let open Mips32dis in
  let (ipc_init, ipc_call, ipc_bind, ipc_raise, ipc_signal) = get_gp_off e in
  let asm = disas_sh (find_sh_by_name e ".text") in
  let dbg_sym = get_sym_tbl e ".symtab" ".strtab" in

  let ipc_init =
    match ipc_init with
    | Some off ->
      find_func_call asm dbg_sym off (fun call ->
        let daemon = get_func_arg call R4 (get_c_str_by_addr e) in
        let fmap = get_func_arg call R5 (get_fmap_str e dbg_sym) in
        (daemon, fmap)
      )
    | None -> []
  in

  let ipc_call =
    match ipc_call with
    | Some off ->
      find_func_call asm dbg_sym off (fun call ->
        let daemon = get_func_arg call R4 (get_c_str_by_addr e) in
        let func = get_func_arg call R5 (get_c_str_by_addr e) in
        (daemon, func)
      )
    | None -> []
  in

  let ipc_bind =
    match ipc_bind with
    | Some off ->
      find_func_call asm dbg_sym off (fun call ->
        get_func_arg call R4 (get_c_str_by_addr e)
      )
    | None -> []
  in

  let ipc_raise =
    match ipc_raise with
    | Some off ->
      find_func_call asm dbg_sym off (fun call ->
        get_func_arg call R4 (get_c_str_by_addr e)
      )
    | None -> []
  in

  let ipc_signal =
    match ipc_signal with
    | Some off ->
      find_func_call asm dbg_sym off (fun call ->
        let daemon = get_func_arg call R4 (get_c_str_by_addr e) in
        let sign = get_func_arg call R5 (get_c_str_by_addr e) in
        let func = get_func_arg call R6 (find_sym_name_by_addr dbg_sym) in
        (daemon, sign, func)
      )
    | None -> []
  in

  output exe (fun exe ->
    let () = output_call exe ipc_init ipc_call in
    output_signal exe ipc_bind ipc_raise ipc_signal
  )

let () =
  if Array.length Sys.argv <> 2 then
    prerr_endline ("Usage: " ^ Sys.argv.(0) ^ " <input>")
  else
    let f = open_in_bin Sys.argv.(1) in
    let buf = IO.read_all f in
    let () = close_in f in
    let elf = Elf.parse buf in
    match elf with
    | None -> prerr_endline "parse ELF failed"
    | Some elf -> proc_elf elf (Filename.basename Sys.argv.(1))
