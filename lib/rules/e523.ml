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
    | _ :: tl -> loop acc tl
  in
  loop [] rest

let extract_modules_field = function
  | Sexp.List (Sexp.Atom "modules" :: rest) -> Some (classify_modules rest)
  | _ -> None

let stanza_modules = function
  | Sexp.List (Sexp.Atom kind :: fields) when is_module_stanza kind ->
      Some (List.filter_map extract_modules_field fields)
  | _ -> None

(** Collect generator-produced module names so they are not falsely reported as
    uncovered. [(ocamllex x)] and [(menhir (modules x))] both produce [x.ml]; a
    [(rule (target foo.ml) ...)] or [(rule (targets a.ml b.ml) ...)] likewise
    produces one or more [.ml] files. *)
let generator_modules stanzas =
  let from_rule fields =
    let target_name atom =
      let a = match atom with Sexp.Atom a -> a | _ -> "" in
      if Filename.check_suffix a ".ml" || Filename.check_suffix a ".mli" then
        [ Filename.remove_extension a ]
      else []
    in
    List.concat_map
      (function
        | Sexp.List [ Sexp.Atom "target"; a ] -> target_name a
        | Sexp.List (Sexp.Atom "targets" :: atoms) ->
            List.concat_map target_name atoms
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
      | _ -> [])
    stanzas

let ml_modules_in_dir dir =
  let entries = try Sys.readdir dir |> Array.to_list with Sys_error _ -> [] in
  List.filter_map
    (fun name ->
      if Filename.check_suffix name ".ml" then
        Some (Filename.chop_suffix name ".ml")
      else None)
    entries

let check_dune path contents =
  match Sexp.Value.parse_string_many contents with
  | Error _ -> None
  | Ok stanzas -> (
      let module_stanzas = List.filter_map stanza_modules stanzas in
      match module_stanzas with
      | [] -> None
      | [ specs ] ->
          (* Single module-accepting stanza. An explicit list is redundant. *)
          if List.exists (function Explicit _ -> true | _ -> false) specs then
            Some (Issue.v { dune = path; kind = Redundant })
          else None
      | _ :: _ :: _ ->
          (* Multiple module-accepting stanzas share a directory. Check that
             every .ml in the dir is covered by some stanza's (modules ...)
             field; if any stanza uses :standard we cannot evaluate it. *)
          let all_specs = List.concat module_stanzas in
          let any_standard =
            List.exists (function Standard -> true | _ -> false) all_specs
          in
          if any_standard then None
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
            else Some (Issue.v { dune = path; kind = Uncovered missing }))

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
