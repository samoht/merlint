(** E500: Missing OCamlformat File *)

(* The directories that should each carry their own [.ocamlformat]: the project
   root and every package discovered in the source tree. A monorepo needs one
   per package directory -- each subtree is published standalone and must format
   consistently on its own -- not just a single file at the umbrella root.
   Several packages can share a directory (a dune-project with multiple
   [(package ...)] stanzas), so the result is deduplicated by directory. *)
let ocamlformat_dirs (ctx : Context.project) =
  let root = Context.fpath_of_path (Context.project_root ctx) in
  let package_dirs =
    Context.index ctx |> Project_index.source_package_list
    |> List.filter_map Project_index.Package.source_dir
  in
  root :: package_dirs

let check (ctx : Context.project) =
  let seen = Hashtbl.create 16 in
  List.filter_map
    (fun dir ->
      let ocamlformat = Fpath.(dir / ".ocamlformat") in
      let key = Fpath.to_string ocamlformat in
      if Hashtbl.mem seen key then None
      else begin
        Hashtbl.add seen key ();
        if Fs.file_exists key then None
        else
          let loc = Loc.in_file (Loc.current_dir_relative ocamlformat) in
          Some (Issue.v ~loc ())
      end)
    (ocamlformat_dirs ctx)

let pp ppf () = Fmt.pf ppf "Missing .ocamlformat file for consistent formatting"

let rule =
  Rule.v ~code:"E500" ~title:"Missing OCamlformat File"
    ~category:Project_structure
    ~hint:
      "Every package needs its own .ocamlformat so each standalone subtree \
       formats consistently, not just the umbrella root. Create one in each \
       directory the linter flags."
    ~examples:[] ~pp (Project check)
