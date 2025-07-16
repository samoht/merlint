(** E500: Missing OCamlformat File *)

let check ctx =
  match ctx with
  | Context.File _ ->
      failwith "E500 is a project-wide rule but received file context"
  | Context.Project ctx ->
      let project_root = ctx.project_root in
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
