let rule_code rule = String.lowercase_ascii (Merlint.Rule.code rule)

let path_exists path = Sys.file_exists path

let fixture_dir rule =
  Filename.concat (Filename.concat "test" "cram") (rule_code rule ^ ".t")

let top_level_entries dir =
  try
    Sys.readdir dir |> Array.to_list
    |> List.map (Filename.concat dir)
    |> List.sort String.compare
  with Sys_error _ -> []

let basename_no_ext path =
  Filename.basename path |> Filename.remove_extension

let is_bad_fixture path =
  let name = basename_no_ext path in
  name = "bad" || String.starts_with ~prefix:"bad" name
  || name = "test_bad"

let is_good_fixture path =
  let name = basename_no_ext path in
  name = "good" || String.starts_with ~prefix:"good" name
  || name = "test_good"

let fixture_paths rule pred =
  let dir = fixture_dir rule in
  top_level_entries dir
  |> List.filter (fun path ->
         pred path
         &&
         (Sys.is_directory path
         || Filename.check_suffix path ".ml"
         || Filename.check_suffix path ".mli"))

let is_ocaml_source path =
  Filename.check_suffix path ".ml" || Filename.check_suffix path ".mli"

let classify_path path =
  if not (path_exists path) then `Missing
  else if Sys.is_directory path then `Dir
  else if is_ocaml_source path then `File
  else `Other

let process_path ~describes ~explicit_files path =
  match classify_path path with
  | `Dir -> describes := Merlint.Dune.describe (Fpath.v path) :: !describes
  | `File -> explicit_files := path :: !explicit_files
  | `Missing | `Other -> ()

let build_dune_describe ~project_root paths =
  match paths with
  | [] -> (Merlint.Dune.describe (Fpath.v project_root), None)
  | _ ->
      let describes = ref [] in
      let explicit_files = ref [] in
      List.iter (process_path ~describes ~explicit_files) paths;
      if !describes = [] && !explicit_files <> [] then
        let project = Merlint.Dune.describe (Fpath.v project_root) in
        let explicit = List.rev_map Fpath.v !explicit_files in
        (project, Some explicit)
      else (Merlint.Dune.merge (List.rev !describes), None)

let run_rule ?index rule paths =
  match paths with
  | [] -> []
  | first :: _ ->
      let project_root = Merlint.Project.root first in
      let filter =
        match Merlint.Filter.parse (Merlint.Rule.code rule) with
        | Ok filter -> filter
        | Error msg -> Alcotest.failf "bad rule filter: %s" msg
      in
      let dune_describe, files_to_analyze =
        build_dune_describe ~project_root paths
      in
      let index =
        match index with
        | Some index -> index
        | None -> lazy (failwith "Monopam_info_index not available")
      in
      let result =
        Merlint.Engine.run ~filter ~dune_describe ?files_to_analyze ~index
          project_root
      in
      result.Merlint.Engine.issues

let check_rule_metadata rule =
  Alcotest.(check bool)
    "rule code is set" true
    (String.length (Merlint.Rule.code rule) > 0);
  Alcotest.(check bool)
    "rule title is set" true
    (String.length (Merlint.Rule.title rule) > 0);
  Alcotest.(check bool)
    "rule hint is set" true
    (String.length (Merlint.Rule.hint rule) > 0)

let assert_bad_fixtures_report rule () =
  let paths = fixture_paths rule is_bad_fixture in
  Alcotest.(check bool)
    "bad fixtures exist" true
    (paths <> []);
  let issues = run_rule rule paths in
  Alcotest.(check bool)
    "bad fixtures report at least one issue" true
    (issues <> [])

let assert_good_fixtures_pass rule () =
  let paths = fixture_paths rule is_good_fixture in
  Alcotest.(check bool)
    "good fixtures exist" true
    (paths <> []);
  let issues = run_rule rule paths in
  Alcotest.(check int) "good fixtures are clean" 0 (List.length issues)

let fixture_suite rule =
  let code = rule_code rule in
  ( code,
    [
      Alcotest.test_case "metadata is complete" `Quick (fun () ->
          check_rule_metadata rule);
      Alcotest.test_case "bad fixtures report issues" `Slow
        (assert_bad_fixtures_report rule);
      Alcotest.test_case "good fixtures pass" `Slow
        (assert_good_fixtures_pass rule);
    ] )
