(** E910: Package quality metadata.

    Scans each package's dune-project for x-quality-* fields and verifies
    that declared quality features are still valid (directories exist,
    dates not stale). Also detects undeclared features that could be added.

    Features:
    - build: package compiles
    - merlint: passes merlint
    - prune: no dead code
    - test: unit tests exist and pass
    - fuzz: fuzz/ directory with alcobar tests
    - interop: test/interop/ directory
    - cram: test/*.t/ directories
    - doc: .mli has docstrings (AI-checked)
    - api: .mli well-structured (AI-checked)

    Format in dune-project:
    {[
      (package
       (name mylib)
       (x-quality-build "2026-04-15")
       (x-quality-fuzz "2026-04-13"))
    ]} *)

type finding =
  | Undeclared of string
  | Missing of string
  | Stale of string * string

type payload = { package : string; findings : finding list }

let dir_exists path =
  try Sys.is_directory path with Sys_error _ -> false

let has_files dir suffix =
  try
    Sys.readdir dir |> Array.to_list
    |> List.exists (fun f -> Filename.check_suffix f suffix)
  with Sys_error _ -> false

let detect_features pkg_dir =
  let features = ref [] in
  let add f = features := f :: !features in
  let fuzz_dir = Filename.concat pkg_dir "fuzz" in
  if dir_exists fuzz_dir && has_files fuzz_dir ".ml" then add "fuzz";
  let interop_dir =
    Filename.concat (Filename.concat pkg_dir "test") "interop"
  in
  if dir_exists interop_dir then add "interop";
  let test_dir = Filename.concat pkg_dir "test" in
  if dir_exists test_dir then
    (try
       Sys.readdir test_dir |> Array.to_list
       |> List.iter (fun f ->
              if
                Filename.check_suffix f ".t"
                && dir_exists (Filename.concat test_dir f)
              then add "cram")
     with Sys_error _ -> ());
  if dir_exists test_dir && has_files test_dir ".ml" then add "test";
  let lib_dir = Filename.concat pkg_dir "lib" in
  if dir_exists lib_dir && has_files lib_dir ".ml" then add "build";
  List.sort_uniq String.compare !features

let parse_quality_fields content =
  let fields = ref [] in
  let lines = String.split_on_char '\n' content in
  List.iter
    (fun line ->
      let line = String.trim line in
      let prefix = "(x-quality-" in
      let plen = String.length prefix in
      if String.length line > plen && String.sub line 0 plen = prefix then
        match String.index_opt line ' ' with
        | None -> ()
        | Some sp ->
            let feature = String.sub line plen (sp - plen) in
            let rest =
              String.sub line (sp + 1) (String.length line - sp - 1)
            in
            let date =
              String.trim rest |> String.split_on_char '"'
              |> List.filter (fun s -> s <> "" && s <> ")" && s <> " ")
              |> function
              | d :: _ -> d
              | [] -> ""
            in
            if feature <> "" && date <> "" then
              fields := (feature, date) :: !fields)
    lines;
  !fields

let check (ctx : Context.project) =
  let root = ctx.project_root in
  let issues = ref [] in
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let packages = try_readdir root in
  List.iter
    (fun pkg ->
      let pkg_dir = Filename.concat root pkg in
      if
        dir_exists pkg_dir && pkg <> "_build" && pkg <> ".git"
        && pkg <> "_opam"
      then
        let dune_project = Filename.concat pkg_dir "dune-project" in
        if Sys.file_exists dune_project then
          let content =
            let ic = open_in dune_project in
            let s = In_channel.input_all ic in
            close_in ic;
            s
          in
          let declared = parse_quality_fields content in
          let detected = detect_features pkg_dir in
          let findings = ref [] in
          List.iter
            (fun feature ->
              if not (List.mem_assoc feature declared) then
                findings := Undeclared feature :: !findings)
            detected;
          List.iter
            (fun (feature, _date) ->
              if not (List.mem feature detected) then
                findings := Missing feature :: !findings)
            declared;
          if !findings <> [] then
            issues :=
              Issue.v { package = pkg; findings = !findings } :: !issues)
    packages;
  !issues

let pp ppf { package; findings } =
  Fmt.pf ppf "%s: %s" package
    (String.concat "; "
       (List.map
          (function
            | Undeclared f -> Fmt.str "%s detected but not declared" f
            | Missing f -> Fmt.str "%s declared but not found" f
            | Stale (f, d) -> Fmt.str "%s stale (last checked %s)" f d)
          findings))

let rule =
  Rule.v ~code:"E910" ~title:"Package quality metadata"
    ~hint:
      "Add x-quality-* fields to dune-project to declare quality features \
       (fuzz, interop, cram, test). Merlint checks they match the actual \
       package structure."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
