include Merlin.Location

let pp ppf loc = Fmt.pf ppf "%s:%d:%d" loc.file loc.start.line loc.start.col

let in_file file =
  Merlin.Location.v ~file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
