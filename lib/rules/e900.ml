(** E900: Wire.Codec without c/ directory *)

type payload = { package : string }

let file_uses_wire ctx path =
  try
    File_view.references_suffix
      (Context.file_view ctx path)
      [ "Wire"; "Codec"; "v" ]
  with File_view.Analysis_error _ -> false

let library_uses_wire ctx lib =
  Project_index.Library.files lib
  |> List.exists (fun fp ->
      let f = Fpath.to_string fp in
      Filename.check_suffix f ".ml"
      && (not (Filename.check_suffix f ".mli"))
      && file_uses_wire ctx f)

let has_c_dir pkg_dir =
  let c = Fpath.to_string (Fpath.add_seg pkg_dir "c") in
  try Fs.is_directory c with Sys_error _ -> false

let check_package ctx pkg =
  let name = Project_index.Package.name pkg in
  match Project_index.Package.source_dir pkg with
  | None -> []
  | Some pkg_dir when has_c_dir pkg_dir -> []
  | Some _ ->
      let libs = Project_index.package_libraries pkg in
      if not (List.exists (library_uses_wire ctx) libs) then []
      else
        let loc = Location.in_file (Filename.concat name "dune-project") in
        [ Issue.v ~loc { package = name } ]

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_packages_nodes
  |> List.concat_map (check_package ctx)

let pp ppf { package } =
  Fmt.pf ppf
    "%s uses Wire.Codec but has no c/ directory for EverParse 3D generation"
    package

let rule =
  Rule.v ~code:"E900" ~title:"Wire.Codec without c/ directory"
    ~category:Code_generation
    ~hint:
      "Add a c/ directory with gen.ml that calls Wire_3d.main to generate .3d \
       files and C validators from the Wire codec definitions. See \
       ocaml-clcw/c/ for the pattern."
    ~examples:[] ~pp (Project check)
