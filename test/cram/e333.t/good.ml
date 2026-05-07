(* Good examples: [<dst>_of_<src>] form, matching stdlib's [int_of_string]. *)

let string_of_int' n = string_of_int n

let hex_of_bytes (b : bytes) =
  let buf = Buffer.create (Bytes.length b * 2) in
  Bytes.iter (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c))) b;
  Buffer.contents buf

let uri_of_path p = "file://" ^ p

let value_of_string s = int_of_string s
let bytes_of_hex h = Bytes.of_string h

(* Action-verb prefixes are fine and remain unflagged. *)
let add_to_set s x = x :: s
let walk_to_root tree = tree
let print_to_buffer buf x = Buffer.add_string buf x
let read_from_buffer buf = Buffer.contents buf
let recover_from_error e = ignore e
