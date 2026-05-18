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

(** Detect quality features from directory structure. *)
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

let quality_words line =
  let t = String.trim line in
  let prefix = "x-quality:" in
  let plen = String.length prefix in
  if String.length t <= plen || String.sub t 0 plen <> prefix then []
  else
    let rest = String.sub t plen (String.length t - plen) in
    String.split_on_char '"' rest
    |> List.filter (fun s ->
        let s = String.trim s in
        s <> "" && s <> "[" && s <> "]" && s <> " ")

let read_policy_file ctx path =
  match
    try Some (Context.file_content ctx path)
    with Sys_error _ | File_view.Analysis_error _ -> None
  with
  | None -> []
  | Some content ->
      String.split_on_char '\n' content |> List.concat_map quality_words

(** Read quality policy from [*.opam] files. *)
let read_policy ctx pkg_dir =
  try
    let files = Fs.readdir pkg_dir |> Array.to_list in
    let opam_files =
      List.filter (fun f -> Filename.check_suffix f ".opam") files
    in
    List.concat_map
      (fun f ->
        let path = Filename.concat pkg_dir f in
        read_policy_file ctx path)
      opam_files
  with Sys_error _ -> []

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

let check_package ctx root pkg =
  let pkg_dir = Filename.concat root pkg in
  if (not (dir_exists pkg_dir)) || List.mem pkg [ "_build"; ".git"; "_opam" ]
  then None
  else
    match read_policy ctx pkg_dir with
    | [] -> None
    | policy -> (
        match package_findings policy (detect_features pkg_dir) with
        | [] -> None
        | findings ->
            let loc = Location.in_file (Filename.concat pkg "dune-project") in
            Some (Issue.v ~loc { package = pkg; findings }))

let check (ctx : Context.project) =
  let root = ctx.project_root in
  let try_readdir d =
    try Fs.readdir d |> Array.to_list with Sys_error _ -> []
  in
  try_readdir root |> List.filter_map (check_package ctx root)

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
