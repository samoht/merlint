(* Bad examples: standalone conversion functions named [<src>_to_<dst>]. *)

let int_to_string n = string_of_int n

let hex_of_bytes (b : bytes) =
  let buf = Buffer.create (Bytes.length b * 2) in
  Bytes.iter (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c))) b;
  Buffer.contents buf

let path_to_uri p = "file://" ^ p

(* These are NOT conversions — action-verb prefixes are exempt. *)
let add_to_set s x = x :: s
let walk_to_root tree = tree
let print_to_buffer buf x = Buffer.add_string buf x
