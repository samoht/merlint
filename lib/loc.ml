let of_typed ~filename (loc : Ocaml_parsing.Location.t) =
  Merlin.Location.v ~file:filename ~start_line:loc.loc_start.pos_lnum
    ~start_col:(loc.loc_start.pos_cnum - loc.loc_start.pos_bol)
    ~end_line:loc.loc_end.pos_lnum
    ~end_col:(loc.loc_end.pos_cnum - loc.loc_end.pos_bol)
