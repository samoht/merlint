(** E523: [(modules ...)] fields must be meaningful and complete.

    Dune picks up every [.ml] / [.mli] in a directory automatically. A
    [(modules ...)] field is only justified when multiple stanzas share a
    directory (and so need to split files between them) or when a
    [:standard \ foo] exclusion keeps a scratch module out of the build.

    This rule flags two cases:

    - {b Redundant:} a dune file has a single module-accepting stanza ([library]
      / [executable(s)] / [test(s)]) with an explicit [(modules foo bar baz)]
      list. Drop the field and let dune auto-discover.
    - {b Uncovered:} a dune file has multiple module-accepting stanzas whose
      [(modules ...)] fields together do not mention every [.ml] file in the
      directory. Some file is falling through and dune is silently dropping it
      from the build. *)

type kind = Redundant | Uncovered of string list
type payload = { dune : string; kind : kind }

let dune_files index =
  Project_index.dune_dirs index
  |> List.map (fun dir -> Filename.concat (Fpath.to_string dir) "dune")

let content ctx path =
  try Some (Context.file_content ctx path)
  with Sys_error _ | File_view.Analysis_error _ -> None

(** [.ml] files dune auto-discovers as modules. Files with extra dots in the
    stem (e.g. [c_tier.everparse.ml]) are NOT modules — OCaml module names can't
    contain dots, so dune treats them as plain text inputs consumed by
    [(select target from (cond -> branch.ml) ...)]. Skip them here so they don't
    trip the uncovered check. *)
let ml_modules_in_dir dir =
  let entries = try Sys.readdir dir |> Array.to_list with Sys_error _ -> [] in
  List.filter_map
    (fun name ->
      if Filename.check_suffix name ".ml" then
        let stem = Filename.chop_suffix name ".ml" in
        if String.contains stem '.' then None else Some stem
      else None)
    entries

let has_explicit_modules (stanza : Dune.File.module_stanza) =
  match stanza.modules with
  | Some (Dune.File.Library.Only _) -> true
  | Some (Dune.File.Library.All_standard | Dune.File.Library.Standard_except _)
  | None ->
      false

let is_implicit_module_stanza (stanza : Dune.File.module_stanza) =
  stanza.modules = None

let uses_standard_modules (stanza : Dune.File.module_stanza) =
  match stanza.modules with
  | Some (Dune.File.Library.All_standard | Dune.File.Library.Standard_except _)
    ->
      true
  | Some (Dune.File.Library.Only _) | None -> false

let uncovered_modules path dune =
  let covered = Dune.File.explicitly_claimed_modules dune in
  let generated =
    Dune.File.generated_modules dune |> List.map String.lowercase_ascii
  in
  Filename.dirname path |> ml_modules_in_dir
  |> List.filter (fun m ->
      let ml = String.lowercase_ascii m in
      not (List.mem ml covered || List.mem ml generated))

let redundant_issue issue = function
  | [ stanza ] when has_explicit_modules stanza -> Some (issue Redundant)
  | [ _ ] | [] -> None
  | _ -> None

let incomplete_issue path issue dune module_stanzas =
  let complete_by_default =
    List.exists is_implicit_module_stanza module_stanzas
    || List.exists uses_standard_modules module_stanzas
  in
  if complete_by_default then None
  else
    match uncovered_modules path dune with
    | [] -> None
    | missing -> Some (issue (Uncovered missing))

let check_dune path contents =
  let display_path = Fpath.v path |> Loc.current_dir_relative in
  let issue kind =
    Issue.v ~loc:(Loc.in_file display_path)
      { dune = Fpath.to_string display_path; kind }
  in
  match Dune.File.of_string contents with
  | Error _ -> None
  | Ok dune when Dune.File.has_nontrivial_include_subdirs dune -> None
  | Ok dune -> (
      match Dune.File.module_stanzas dune with
      | [] -> None
      | [ _ ] as stanzas -> redundant_issue issue stanzas
      | stanzas -> incomplete_issue path issue dune stanzas)

let check (ctx : Context.project) =
  let dunes = dune_files (Context.index ctx) in
  List.filter_map
    (fun path ->
      match content ctx path with
      | None -> None
      | Some contents -> check_dune path contents)
    dunes

let pp ppf { dune; kind } =
  match kind with
  | Redundant ->
      Fmt.pf ppf
        "%s has a single stanza with a redundant (modules ...) field; drop it \
         and let dune auto-discover the .ml files"
        dune
  | Uncovered files ->
      Fmt.pf ppf
        "%s has multiple stanzas but the (modules ...) fields do not cover %a; \
         those .ml files are silently excluded from the build"
        dune
        Fmt.(list ~sep:comma string)
        files

let rule =
  Rule.v ~code:"E523" ~title:"Redundant or incomplete (modules ...) in dune"
    ~category:Rule.Project_structure
    ~hint:
      "A dune file with a single library/executable/test stanza doesn't need \
       (modules ...) — dune auto-discovers every .ml in the directory. When \
       multiple stanzas share a directory the (modules ...) fields must \
       together cover every .ml file, otherwise some module is silently \
       dropped. Prefer splitting into sibling directories when the stanza \
       split is a design choice rather than a build requirement."
    ~examples:[] ~pp (Project check)
