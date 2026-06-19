(** E900: Wire.Codec without a wired c/ directory *)

(* [Missing] is no c/ at all. [Unwired] is a c/ that exists but lacks the files
   that build it ([gen.ml] generator, [dune], generated [dune.inc]), so the
   EverParse projection never runs even though the directory is present. *)
type reason = Missing | Unwired of string list
type payload = { package : string; reason : reason }

let file_uses_wire ctx path =
  try
    File_view.references_suffix
      (Context.file_view ctx path)
      [ "Wire"; "Codec"; "v" ]
  with File_view.Analysis_error _ -> false

let library_uses_wire ctx lib =
  Project_index.Library.files lib
  |> List.exists (fun fp ->
      let file = Context.resolve ctx fp in
      let f = Fpath.to_string fp in
      Filename.check_suffix f ".ml"
      && (not (Filename.check_suffix f ".mli"))
      && ctx.Context.in_analyze_set file
      && file_uses_wire ctx file)

let c_dir pkg_dir = Fpath.add_seg pkg_dir "c"

let has_c_dir pkg_dir =
  try Fs.is_directory (Fpath.to_string (c_dir pkg_dir))
  with Sys_error _ -> false

(* A c/ directory is wired into the build when it carries the generator
   ([gen.ml]), the [dune] that compiles it, and the generated rules it includes
   ([dune.inc]). Any missing one means the projection never builds. *)
let wiring_files = [ "gen.ml"; "dune"; "dune.inc" ]

let missing_wiring pkg_dir =
  let c = c_dir pkg_dir in
  List.filter
    (fun n -> not (Fs.file_exists (Fpath.to_string (Fpath.add_seg c n))))
    wiring_files

let is_wire_provider pkg = Project_index.Package.name pkg = "wire"

let check_package ctx pkg =
  let name = Project_index.Package.name pkg in
  match Project_index.Package.source_dir pkg with
  | None -> []
  | Some _ when is_wire_provider pkg -> []
  | Some pkg_dir -> (
      let reason =
        if not (has_c_dir pkg_dir) then Some Missing
        else
          match missing_wiring pkg_dir with [] -> None | m -> Some (Unwired m)
      in
      match reason with
      | None -> []
      | Some reason ->
          let libs = Project_index.package_libraries pkg in
          if not (List.exists (library_uses_wire ctx) libs) then []
          else
            let file =
              match reason with
              | Missing -> "dune-project"
              | Unwired _ -> "c/dune"
            in
            let loc = Location.in_file (Filename.concat name file) in
            [ Issue.v ~loc { package = name; reason } ])

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.concat_map (check_package ctx)

let pp ppf { package; reason } =
  match reason with
  | Missing ->
      Fmt.pf ppf
        "%s uses Wire.Codec but has no c/ directory for EverParse 3D generation"
        package
  | Unwired missing ->
      Fmt.pf ppf
        "%s has a c/ directory but it is not wired into the build (missing \
         %s), so the EverParse 3D generation never runs"
        package
        (String.concat ", " missing)

let rule =
  Rule.v ~code:"E900" ~title:"Wire.Codec without a wired c/ directory"
    ~category:Code_generation
    ~hint:
      "Add a c/ directory whose gen.ml calls Wire_3d.main ~mode:`Doc to \
       project the Wire codecs into a single <Name>.3d EverParse spec and \
       validator, and wire it into the build with a dune that compiles gen and \
       includes the generated dune.inc. See ocaml-clcw/c/ for the pattern."
    ~examples:[] ~pp (Project check)
