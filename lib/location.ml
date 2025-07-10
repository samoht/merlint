(** Shared location types and utilities *)

type t = { file : string; line : int; col : int }

let create ~file ~line ~col = { file; line; col }
let pp ppf loc = Fmt.pf ppf "%s:%d:%d" loc.file loc.line loc.col

let compare l1 l2 =
  let fc = String.compare l1.file l2.file in
  if fc <> 0 then fc else compare l1.line l2.line

type range = {
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}

type extended = {
  file : string;
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}

let to_simple ext =
  { file = ext.file; line = ext.start_line; col = ext.start_col }

let create_extended ~file ~start_line ~start_col ~end_line ~end_col =
  { file; start_line; start_col; end_line; end_col }
