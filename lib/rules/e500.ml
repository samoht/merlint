(** E500: Missing OCamlformat File *)

let check (ctx : Context.project) =
  let project_root = ctx.project_root in
  let ocamlformat_path = Filename.concat project_root ".ocamlformat" in
  if not (Sys.file_exists ocamlformat_path) then [ Issue.v () ] else []

let pp ppf () =
  Fmt.pf ppf "Project is missing .ocamlformat file for consistent formatting"

let rule =
  Rule.v ~code:"E500" ~title:"Missing OCamlformat File"
    ~category:Project_structure
    ~hint:
      "All OCaml projects should have a .ocamlformat file in the root \
       directory to ensure consistent code formatting. Create one with your \
       preferred settings."
    ~examples:[] ~pp (Project check)
