(* Bad examples: standalone conversion functions named [<src>_to_<dst>] or
   [<dst>_from_<src>] — both should be rewritten to [<dst>_of_<src>]. *)

let int_to_string n = string_of_int n

let bytes_to_hex (b : bytes) =
  let buf = Buffer.create (Bytes.length b * 2) in
  Bytes.iter (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c))) b;
  Buffer.contents buf

let path_to_uri p = "file://" ^ p

(* [_from_] form: [<dst>_from_<src>] should rewrite to [<dst>_of_<src>]. *)
let value_from_string s = int_of_string s
let bytes_from_hex h = Bytes.of_string h

(* These are NOT conversions — action-verb prefixes are exempt. *)
let add_to_set s x = x :: s
let walk_to_root tree = tree
let print_to_buffer buf x = Buffer.add_string buf x
let read_from_buffer buf = Buffer.contents buf
let recover_from_error e = ignore e
