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

let find_dune_files root =
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let is_dir p = try Sys.is_directory p with Sys_error _ -> false in
  let rec walk dir acc =
    List.fold_left
      (fun acc name ->
        if
          name = "_build" || name = "_opam" || name = ".git"
          || String.starts_with ~prefix:"." name
        then acc
        else
          let p = Filename.concat dir name in
          if is_dir p then walk p acc
          else if name = "dune" then p :: acc
          else acc)
      acc (try_readdir dir)
  in
  walk root []

let read_file path =
  try
    let ic = open_in path in
    let n = in_channel_length ic in
    let s = really_input_string ic n in
    close_in ic;
    Some s
  with Sys_error _ -> None

let is_module_stanza = function
  | "library" | "executable" | "executables" | "test" | "tests" -> true
  | _ -> false

(** Interpret a [(modules ...)] field.

    [Standard]: uses [:standard] (with or without exclusions) or other patterns
    we cannot resolve statically.

    [Explicit names]: plain list of module-name atoms. *)
type modules_spec = Standard | Explicit of string list

let classify_modules rest =
  let rec loop acc = function
    | [] -> Explicit (List.rev acc)
    | Sexp.Atom a :: _ when String.length a > 0 && a.[0] = ':' -> Standard
    | Sexp.Atom "\\" :: _ -> Standard
    | Sexp.Atom a :: tl -> loop (a :: acc) tl
    | Sexp.List _ :: _ -> Standard
  in
  loop [] rest

let extract_modules_field = function
  | Sexp.List (Sexp.Atom "modules" :: rest) -> Some (classify_modules rest)
  | _ -> None

let stanza_modules = function
  | Sexp.List (Sexp.Atom kind :: fields) when is_module_stanza kind ->
      Some (List.filter_map extract_modules_field fields)
  | _ -> None

let module_of_atom atom =
  let a = match atom with Sexp.Atom a -> a | _ -> "" in
  if Filename.check_suffix a ".ml" || Filename.check_suffix a ".mli" then
    [ Filename.remove_extension a ]
  else []

(** Pull module names produced by a [(select target from (cond -> branch) ...)]
    form inside a [(libraries ...)] field. Both the generated [target] and every
    source-side [branch] file are added, since both sit on disk (branches as
    source, target as build output) and neither should trip the uncovered check.
*)
let select_modules libs =
  let from_branch = function
    | Sexp.List items ->
        List.concat_map
          (function Sexp.Atom a -> module_of_atom (Sexp.Atom a) | _ -> [])
          items
    | _ -> []
  in
  List.concat_map
    (function
      | Sexp.List (Sexp.Atom "select" :: Sexp.Atom target :: rest) ->
          module_of_atom (Sexp.Atom target) @ List.concat_map from_branch rest
      | _ -> [])
    libs

(** Module name produced by [(generate_sites_module (module foo) ...)]. *)
let generate_sites_module_name fields =
  List.concat_map
    (function
      | Sexp.List [ Sexp.Atom "module"; Sexp.Atom name ] -> [ name ] | _ -> [])
    fields

(** Modules pulled in by a single [library]/[executable(s)]/[test(s)] stanza's
    sub-fields (select targets, generate_sites_module, copy_files outputs). *)
let stanza_generator_modules fields =
  List.concat_map
    (function
      | Sexp.List (Sexp.Atom "libraries" :: libs) -> select_modules libs
      | Sexp.List (Sexp.Atom "generate_sites_module" :: gs) ->
          generate_sites_module_name gs
      | _ -> [])
    fields

(** Modules from [(copy_files ...)] / [(copy_files# ...)] stanzas. The source
    argument may be a plain atom [../a/foo.ml] or [(files ../a/foo.ml)]. Globs
    like [../a/*.ml] are not expanded — the result is approximate but errs on
    the side of not flagging real generated files. *)
let copy_files_modules rest =
  let from_atom = function
    | Sexp.Atom a when not (String.contains a '*') ->
        module_of_atom (Sexp.Atom (Filename.basename a))
    | _ -> []
  in
  List.concat_map
    (function
      | Sexp.Atom _ as a -> from_atom a
      | Sexp.List (Sexp.Atom "files" :: atoms) ->
          List.concat_map from_atom atoms
      | Sexp.List _ -> [])
    rest

(** Collect generator-produced module names so they are not falsely reported as
    uncovered. Covered dune constructs:

    - [(ocamllex x)] / [(menhir (modules x))] produce [x.ml].
    - [(rule (target foo.ml) ...)] / [(rule (targets a.ml b.ml) ...)] produce
      the listed [.ml] files.
    - [(libraries (select t from (c -> b) ...))] inside a stanza produces the
      [t] target and every branch file [b].
    - [(generate_sites_module (module foo) ...)] inside a library stanza
      produces [foo.ml].
    - [(copy_files foo.ml)] / [(copy_files (files foo.ml))] drops [foo.ml] into
      the current directory. *)
let generator_modules stanzas =
  let from_rule fields =
    List.concat_map
      (function
        | Sexp.List [ Sexp.Atom "target"; a ] -> module_of_atom a
        | Sexp.List (Sexp.Atom "targets" :: atoms) ->
            List.concat_map module_of_atom atoms
        | _ -> [])
      fields
  in
  List.concat_map
    (function
      | Sexp.List (Sexp.Atom "ocamllex" :: rest) ->
          List.filter_map (function Sexp.Atom a -> Some a | _ -> None) rest
      | Sexp.List (Sexp.Atom "menhir" :: fields) ->
          List.concat_map
            (function
              | Sexp.List (Sexp.Atom "modules" :: atoms) ->
                  List.filter_map
                    (function Sexp.Atom a -> Some a | _ -> None)
                    atoms
              | _ -> [])
            fields
      | Sexp.List (Sexp.Atom "rule" :: fields) -> from_rule fields
      | Sexp.List (Sexp.Atom kind :: fields) when is_module_stanza kind ->
          stanza_generator_modules fields
      | Sexp.List (Sexp.Atom cf :: rest)
        when cf = "copy_files" || cf = "copy_files#" ->
          copy_files_modules rest
      | _ -> [])
    stanzas

(** Directory-scanning directives that invalidate single-directory assumptions.
    When [(include_subdirs unqualified)] or [(include_subdirs qualified)] is
    present, modules in subdirectories belong to the stanza; we cannot decide
    coverage without walking them, so the rule bails out. [(include_subdirs no)]
    is the default and does not affect anything. *)
let has_nontrivial_include_subdirs stanzas =
  List.exists
    (function
      | Sexp.List [ Sexp.Atom "include_subdirs"; Sexp.Atom mode ]
        when mode = "unqualified" || mode = "qualified" ->
          true
      | _ -> false)
    stanzas

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

let check_dune path contents =
  match Sexp.Value.parse_string_many contents with
  | Error _ -> None
  | Ok stanzas when has_nontrivial_include_subdirs stanzas -> None
  | Ok stanzas -> (
      let module_stanzas = List.filter_map stanza_modules stanzas in
      match module_stanzas with
      | [] -> None
      | [ specs ] ->
          (* Single module-accepting stanza. An explicit list is redundant. *)
          if List.exists (function Explicit _ -> true | _ -> false) specs then
            Some
              (Issue.v ~loc:(Location.in_file path)
                 { dune = path; kind = Redundant })
          else None
      | _ :: _ :: _ ->
          (* Multiple module-accepting stanzas share a directory. If any
             stanza has no [(modules ...)] field at all, it implicitly claims
             every remaining file via dune's auto-discovery, so coverage is
             trivially complete. Likewise if any stanza uses [:standard] we
             cannot evaluate it. *)
          let any_implicit =
            List.exists (function [] -> true | _ -> false) module_stanzas
          in
          let all_specs = List.concat module_stanzas in
          let any_standard =
            List.exists (function Standard -> true | _ -> false) all_specs
          in
          if any_implicit || any_standard then None
          else
            let covered =
              List.concat_map
                (function Explicit xs -> xs | Standard -> [])
                all_specs
              |> List.map String.lowercase_ascii
            in
            let dir = Filename.dirname path in
            let generated =
              generator_modules stanzas |> List.map String.lowercase_ascii
            in
            let files = ml_modules_in_dir dir in
            let missing =
              List.filter
                (fun m ->
                  let ml = String.lowercase_ascii m in
                  not (List.mem ml covered || List.mem ml generated))
                files
            in
            if missing = [] then None
            else
              Some
                (Issue.v ~loc:(Location.in_file path)
                   { dune = path; kind = Uncovered missing }))

let check (ctx : Context.project) =
  let dunes = find_dune_files ctx.project_root in
  List.filter_map
    (fun path ->
      match read_file path with
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
