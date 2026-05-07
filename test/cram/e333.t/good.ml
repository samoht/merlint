(* Good examples: [<dst>_of_<src>] form, matching stdlib's [int_of_string]. *)

let string_of_int' n = string_of_int n

let hex_of_bytes (b : bytes) =
  let buf = Buffer.create (Bytes.length b * 2) in
  Bytes.iter (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c))) b;
  Buffer.contents buf

let uri_of_path p = "file://" ^ p

let value_of_string s = int_of_string s
let bytes_of_hex h = Bytes.of_string h

(* These have [_to_]/[_from_] in the name but are NOT conversions by type:
   the type-shape check excludes multi-arrow and unit-return functions. *)

let add_to_set s x = x :: s
(* val add_to_set : 'a list -> 'a -> 'a list — two arrows, not flagged. *)

let print_to_buffer buf x = Buffer.add_string buf x
(* val print_to_buffer : Buffer.t -> string -> unit — unit return, not flagged. *)

let recover_from_error e = ignore e
(* val recover_from_error : 'a -> unit — unit return, not flagged. *)
