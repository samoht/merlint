(* Bad examples: single-arrow [T1 -> T2] with non-unit [T2] — these are
   real conversions and should use the [<dst>_of_<src>] form. *)

let int_to_string n = string_of_int n

let bytes_to_hex (b : bytes) =
  let buf = Buffer.create (Bytes.length b * 2) in
  Bytes.iter (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c))) b;
  Buffer.contents buf

let path_to_uri p = "file://" ^ p

let value_from_string s = int_of_string s
let bytes_from_hex h = Bytes.of_string h
