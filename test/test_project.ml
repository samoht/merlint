open Merlint

let test_find_project_root () =
  let cwd = Sys.getcwd () in
  let project_root = Project.root cwd in
  Alcotest.(check bool)
    "found project root" true
    (Sys.file_exists (Filename.concat project_root "dune-project"))

let test_root_from_file () =
  let test_file = "lib/project.ml" in
  if Sys.file_exists test_file then
    let project_root = Project.root test_file in
    Alcotest.(check bool)
      "found project root from file" true
      (Sys.file_exists (Filename.concat project_root "dune-project"))
  else ()

let test_root_from_dir () =
  let test_dir = "lib" in
  if Sys.file_exists test_dir && Sys.is_directory test_dir then
    let project_root = Project.root test_dir in
    Alcotest.(check bool)
      "found project root from directory" true
      (Sys.file_exists (Filename.concat project_root "dune-project"))
  else ()

let test_workspace_root () =
  let cwd = Sys.getcwd () in
  let ws = Project.workspace_root cwd in
  Alcotest.(check bool)
    "workspace root has dune-project" true
    (Sys.file_exists (Filename.concat ws "dune-project"))

let test_workspace_root_is_outermost () =
  let cwd = Sys.getcwd () in
  let nearest = Project.root cwd in
  let ws = Project.workspace_root cwd in
  (* Workspace root should be at the same level or higher than nearest root *)
  Alcotest.(check bool)
    "workspace root <= nearest root length" true
    (String.length ws <= String.length nearest)

let with_temp_tree f =
  let tmp = Filename.temp_dir "merlint_test" "" in
  Fun.protect
    ~finally:(fun () -> ignore (Sys.command ("rm -rf " ^ tmp)))
    (fun () -> f tmp)

let write_file path content =
  let dir = Filename.dirname path in
  ignore (Sys.command ("mkdir -p " ^ dir));
  let oc = open_out path in
  output_string oc content;
  close_out oc

let test_config_files_empty () =
  with_temp_tree @@ fun tmp ->
  let configs = Project.config_files tmp in
  Alcotest.(check (list string)) "no configs" [] configs

let test_config_files_single () =
  with_temp_tree @@ fun tmp ->
  write_file (Filename.concat tmp "dune-project") "(lang dune 3.0)";
  write_file (Filename.concat tmp "merlint.toml") "max-complexity = 5";
  let configs = Project.config_files tmp in
  Alcotest.(check int) "one config" 1 (List.length configs);
  Alcotest.(check bool)
    "is merlint.toml" true
    (Filename.basename (List.hd configs) = "merlint.toml")

let test_config_files_nested () =
  with_temp_tree @@ fun tmp ->
  let sub = Filename.concat tmp "sub" in
  Unix.mkdir sub 0o755;
  write_file (Filename.concat tmp "dune-project") "(lang dune 3.0)";
  write_file
    (Filename.concat tmp "merlint.toml")
    "[[rules]]\nfiles = \"sub/bad.ml\"\nexclude = [\"E100\"]";
  write_file (Filename.concat sub "dune-project") "(lang dune 3.0)";
  write_file (Filename.concat sub "merlint.toml") "max-complexity = 15";
  let configs = Project.config_files sub in
  Alcotest.(check int) "two configs" 2 (List.length configs);
  (* Outermost first *)
  Alcotest.(check bool)
    "outermost first" true
    (String.length (List.nth configs 0) < String.length (List.nth configs 1))

let test_config_files_workspace_boundary () =
  with_temp_tree @@ fun tmp ->
  (* Only root has dune-project, subdirectory does not *)
  let sub = Filename.concat tmp "sub" in
  Unix.mkdir sub 0o755;
  write_file (Filename.concat tmp "dune-project") "(lang dune 3.0)";
  write_file
    (Filename.concat tmp "merlint.toml")
    "[[rules]]\nfiles = \"sub/f.ml\"\nexclude = [\"E200\"]";
  let configs = Project.config_files sub in
  Alcotest.(check int) "root config found" 1 (List.length configs)

let test_config_merge_settings () =
  with_temp_tree @@ fun tmp ->
  let sub = Filename.concat tmp "sub" in
  Unix.mkdir sub 0o755;
  write_file (Filename.concat tmp "dune-project") "(lang dune 3.0)";
  write_file (Filename.concat tmp "merlint.toml") "max-complexity = 20";
  write_file (Filename.concat sub "dune-project") "(lang dune 3.0)";
  write_file (Filename.concat sub "merlint.toml") "max-complexity = 5";
  let config = Config.load_from_path sub in
  (* Closer config (sub) should override outer (root) *)
  Alcotest.(check int) "closer overrides" 5 config.max_complexity

let test_config_merge_exclusions () =
  with_temp_tree @@ fun tmp ->
  let sub = Filename.concat tmp "sub" in
  Unix.mkdir sub 0o755;
  write_file (Filename.concat tmp "dune-project") "(lang dune 3.0)";
  write_file
    (Filename.concat tmp "merlint.toml")
    "[[rules]]\nfiles = \"sub/a.ml\"\nexclude = [\"E100\"]";
  write_file (Filename.concat sub "dune-project") "(lang dune 3.0)";
  write_file
    (Filename.concat sub "merlint.toml")
    "[[rules]]\nfiles = \"b.ml\"\nexclude = [\"E200\"]";
  let config = Config.load_from_path sub in
  (* Both exclusions should be present *)
  Alcotest.(check bool)
    "E100 excluded for sub/a.ml" true
    (Rule_config.should_exclude config.exclusions ~rule:"E100" ~file:"sub/a.ml");
  Alcotest.(check bool)
    "E200 excluded for b.ml" true
    (Rule_config.should_exclude config.exclusions ~rule:"E200" ~file:"b.ml")

let suite =
  ( "project",
    [
      ("find project root", `Quick, test_find_project_root);
      ("project root from file", `Quick, test_root_from_file);
      ("project root from directory", `Quick, test_root_from_dir);
      ("workspace root", `Quick, test_workspace_root);
      ("workspace root is outermost", `Quick, test_workspace_root_is_outermost);
      ("config files empty", `Quick, test_config_files_empty);
      ("config files single", `Quick, test_config_files_single);
      ("config files nested", `Quick, test_config_files_nested);
      ( "config files workspace boundary",
        `Quick,
        test_config_files_workspace_boundary );
      ("config merge settings", `Quick, test_config_merge_settings);
      ("config merge exclusions", `Quick, test_config_merge_exclusions);
    ] )
