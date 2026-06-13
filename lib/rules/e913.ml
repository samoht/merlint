(** E913: Missing package metadata.

    Every opam package ships a small set of human-facing metadata files at its
    source root: a [README.md] describing what the package is and how to use it,
    and a license file ([LICENSE.md] or [LICENSE]) stating the terms it is
    distributed under. These travel with the package when it is split out to its
    own repository, so a package missing them publishes without documentation or
    a license.

    A finding is a source package whose root is missing one or more of the
    required metadata files. A package that builds no library and no executable
    -- a pure dependency-pinning aggregator like a monorepo root package -- has
    no code to document or license and is exempt. *)

type kind = Readme | License
type payload = { package : string; missing : kind list }

module P = Project_index.Package

(* Accepted basenames for each requirement, matched case-insensitively with the
   extension ignored: README.md, LICENSE, COPYING.txt all count. *)
let readme_names = [ "readme" ]
let license_names = [ "license"; "copying" ]

let basename_stem name =
  Filename.basename name |> Filename.remove_extension |> String.lowercase_ascii

let has_file entries names =
  List.exists (fun e -> List.mem (basename_stem e) names) entries

let missing_kinds dir =
  let entries = Fs.readdir_or_empty (Fpath.to_string dir) in
  let add present kind acc = if present then acc else kind :: acc in
  []
  |> add (has_file entries license_names) License
  |> add (has_file entries readme_names) Readme

let loc_in_project path = Loc.current_dir_relative path |> Loc.in_file

let check_package pkg =
  match P.source_dir pkg with
  | None -> None
  | Some dir -> (
      match missing_kinds dir with
      | [] -> None
      | missing ->
          let loc = loc_in_project Fpath.(dir / "dune-project") in
          Some (Issue.v ~loc { package = P.name pkg; missing }))

(* Several opam packages can share one source directory; report each missing
   file once per directory rather than once per package. *)
let dedup pkgs =
  let seen = Hashtbl.create 16 in
  List.filter
    (fun pkg ->
      match P.source_dir pkg with
      | None -> true
      | Some dir ->
          let key = Fpath.to_string dir in
          if Hashtbl.mem seen key then false
          else begin
            Hashtbl.add seen key ();
            true
          end)
    pkgs

(* A package that builds no library and no executable -- a pure
   dependency-pinning aggregator, such as a monorepo root package -- ships no
   code of its own, so there is nothing to document or license. *)
let builds_code pkg =
  Project_index.package_libraries pkg <> [] || P.executable_stanzas pkg <> []

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.filter (fun pkg -> (not (P.is_anonymous pkg)) && builds_code pkg)
  |> dedup
  |> List.filter_map check_package

let kind_file = function Readme -> "README.md" | License -> "LICENSE.md"

let pp ppf { package; missing } =
  Fmt.pf ppf "%s: missing %s" package
    (String.concat ", " (List.map kind_file missing))

let rule =
  Rule.v ~code:"E913" ~title:"Missing package metadata"
    ~hint:
      "Add the human-facing metadata files every opam package ships at its \
       source root: a README.md describing the package and a license file \
       (LICENSE.md). These travel with the package when it is split out to its \
       own repository."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
