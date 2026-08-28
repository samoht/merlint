(** E910: Package quality policy enforcement.

    Reads quality policy from [*.opam.template] files:
    {[
     x-quality: ["build" "test" "fuzz" "doc"]
    ]}

    Checks that declared quality features actually exist in the package.
    Reports:
    - Missing: declared in policy but not present (error)
    - Undeclared: present but not in policy (suggestion) *)

type finding = Missing of string | Undeclared of string
type payload = { package : string; findings : finding list }

let string_of = function Opam.Value.String (s, _) -> Some s | _ -> None

let quality_from_raw_opam content =
  match Opam.field "x-quality" content with
  | None -> []
  | Some (Opam.Value.String (s, _)) -> [ s ]
  | Some (Opam.Value.List (xs, _)) -> List.filter_map string_of xs
  | Some _ -> []

let dir_exists path = try Fs.is_directory path with Sys_error _ -> false

let has_files dir suffix =
  try
    Fs.readdir dir |> Array.to_list
    |> List.exists (fun f -> Filename.check_suffix f suffix)
  with Sys_error _ -> false

let has_doc_files pkg_dir =
  Fs.file_exists (Filename.concat pkg_dir "README.md")
  || has_files pkg_dir ".mld"
  || has_files (Filename.concat pkg_dir "doc") ".mld"

let has_cram_tests test_dir =
  if not (dir_exists test_dir) then false
  else
    try
      Fs.readdir test_dir |> Array.to_list
      |> List.exists (fun f ->
          Filename.check_suffix f ".t"
          && dir_exists (Filename.concat test_dir f))
    with Sys_error _ -> false

let add_if present feature features =
  if present then feature :: features else features

let detect_features pkg_dir =
  let lib_dir = Filename.concat pkg_dir "lib" in
  let test_dir = Filename.concat pkg_dir "test" in
  let fuzz_dir = Filename.concat pkg_dir "fuzz" in
  let interop_dir = Filename.concat test_dir "interop" in
  let has_lib = dir_exists lib_dir && has_files lib_dir ".ml" in
  []
  |> add_if
       (has_lib && Fs.file_exists (Filename.concat pkg_dir "dune-project"))
       "build"
  |> add_if (dir_exists test_dir && has_files test_dir ".ml") "test"
  |> add_if (dir_exists fuzz_dir && has_files fuzz_dir ".ml") "fuzz"
  |> add_if (has_doc_files pkg_dir) "doc"
  |> add_if (dir_exists interop_dir) "interop"
  |> add_if (has_cram_tests test_dir) "cram"
  |> List.sort_uniq String.compare

let package_findings policy detected =
  let missing =
    policy
    |> List.filter (fun feature -> not (List.mem feature detected))
    |> List.map (fun feature -> Missing feature)
  in
  let undeclared =
    detected
    |> List.filter (fun feature -> not (List.mem feature policy))
    |> List.map (fun feature -> Undeclared feature)
  in
  missing @ undeclared

let loc_in_project path = Loc.current_dir_relative path |> Loc.in_file

let check_package pkg =
  match
    (Project_index.Package.source_dir pkg, Project_index.Package.raw_opam pkg)
  with
  | _, None -> None
  | None, _ -> None
  | Some dir, Some raw_opam -> (
      let policy = quality_from_raw_opam raw_opam in
      if policy = [] then None
      else
        let name = Project_index.Package.name pkg in
        let detected = detect_features (Fpath.to_string dir) in
        match package_findings policy detected with
        | [] -> None
        | findings ->
            let loc = loc_in_project Fpath.(dir / "dune-project") in
            Some (Issue.v ~loc { package = name; findings }))

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.filter_map check_package

let pp ppf { package; findings } =
  Fmt.pf ppf "%s: %s" package
    (String.concat "; "
       (List.map
          (function
            | Missing f -> Fmt.str "%s required by x-quality but missing" f
            | Undeclared f ->
                Fmt.str "%s present, consider adding to x-quality" f)
          findings))

let rule =
  Rule.v ~code:"E910" ~title:"Package quality policy"
    ~hint:
      "Add x-quality field to *.opam.template to declare required quality \
       features. Merlint checks that declared features actually exist."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
