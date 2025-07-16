(** Shared location types and utilities *)

type t = {
  file : string;
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}

let create ~file ~start_line ~start_col ~end_line ~end_col =
  { file; start_line; start_col; end_line; end_col }

let pp ppf loc = Fmt.pf ppf "%s:%d:%d" loc.file loc.start_line loc.start_col

let compare l1 l2 =
  let fc = String.compare l1.file l2.file in
  if fc <> 0 then fc
  else
    let line_c = compare l1.start_line l2.start_line in
    if line_c <> 0 then line_c else compare l1.start_col l2.start_col
