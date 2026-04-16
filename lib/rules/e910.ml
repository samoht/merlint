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

let dir_exists path = try Sys.is_directory path with Sys_error _ -> false

let has_files dir suffix =
  try
    Sys.readdir dir |> Array.to_list
    |> List.exists (fun f -> Filename.check_suffix f suffix)
  with Sys_error _ -> false

(** Detect quality features from directory structure. *)
let detect_features pkg_dir =
  let features = ref [] in
  let add f = features := f :: !features in
  let lib_dir = Filename.concat pkg_dir "lib" in
  let test_dir = Filename.concat pkg_dir "test" in
  let fuzz_dir = Filename.concat pkg_dir "fuzz" in
  let interop_dir = Filename.concat test_dir "interop" in
  let has_lib = dir_exists lib_dir && has_files lib_dir ".ml" in
  if has_lib && Sys.file_exists (Filename.concat pkg_dir "dune-project") then
    add "build";
  if dir_exists test_dir && has_files test_dir ".ml" then add "test";
  if dir_exists fuzz_dir && has_files fuzz_dir ".ml" then add "fuzz";
  if dir_exists interop_dir then add "interop";
  (if dir_exists test_dir then
     try
       Sys.readdir test_dir |> Array.to_list
       |> List.iter (fun f ->
           if
             Filename.check_suffix f ".t"
             && dir_exists (Filename.concat test_dir f)
           then add "cram")
     with Sys_error _ -> ());
  List.sort_uniq String.compare !features

(** Read quality policy from [*.opam] files. *)
let read_policy pkg_dir =
  try
    let files = Sys.readdir pkg_dir |> Array.to_list in
    let opam_files =
      List.filter (fun f -> Filename.check_suffix f ".opam") files
    in
    List.concat_map
      (fun f ->
        let path = Filename.concat pkg_dir f in
        try
          let ic = open_in path in
          let content = In_channel.input_all ic in
          close_in ic;
          let lines = String.split_on_char '\n' content in
          List.concat_map
            (fun line ->
              let t = String.trim line in
              let prefix = "x-quality:" in
              let plen = String.length prefix in
              if String.length t > plen && String.sub t 0 plen = prefix then
                let rest = String.sub t plen (String.length t - plen) in
                String.split_on_char '"' rest
                |> List.filter (fun s ->
                    let s = String.trim s in
                    s <> "" && s <> "[" && s <> "]" && s <> " ")
              else [])
            lines
        with Sys_error _ -> [])
      opam_files
  with Sys_error _ -> []

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
        dir_exists pkg_dir && pkg <> "_build" && pkg <> ".git" && pkg <> "_opam"
      then
        let policy = read_policy pkg_dir in
        if policy <> [] then (
          let detected = detect_features pkg_dir in
          let findings = ref [] in
          (* Policy violations: declared but missing *)
          List.iter
            (fun feature ->
              if not (List.mem feature detected) then
                findings := Missing feature :: !findings)
            policy;
          (* Suggestions: present but not declared *)
          List.iter
            (fun feature ->
              if not (List.mem feature policy) then
                findings := Undeclared feature :: !findings)
            detected;
          if !findings <> [] then
            issues := Issue.v { package = pkg; findings = !findings } :: !issues))
    packages;
  !issues

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
