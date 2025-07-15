(** E500: Missing OCamlformat File *)

let check project_root =
  let ocamlformat_path = Filename.concat project_root ".ocamlformat" in
  if not (Sys.file_exists ocamlformat_path) then
    [
      Issue.Missing_ocamlformat_file
        {
          location =
            Location.create ~file:project_root ~start_line:1 ~start_col:1
              ~end_line:1 ~end_col:1;
        };
    ]
  else []
