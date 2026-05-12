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

(* Inside a module whose abstract type is [t], the [t] in conversion
   names is implicit; [<X>_of_t] and [t_of_<X>] should collapse to
   [to_<X>] and [of_<X>]. *)

type t = int

let int_of_t (x : t) = x
let t_of_int n : t = n

(* [to_<X>] is only canonical when the source is the module's [t] (or
   one of [t]'s transparent aliases when the [.ml] omits an annotation).
   A function whose source is unrelated to [t] is a disguised
   [<src>_to_<X>] and must use [<X>_of_<src>] instead. *)

let to_pair (s : string) = (s, s)
