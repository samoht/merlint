let rule_code rule = String.lowercase_ascii (Merlint.Rule.code rule)
let path_exists path = Sys.file_exists path

let cram_root () =
  [
    Filename.concat ".." "cram";
    Filename.concat (Filename.concat "test" "cram") "";
    Filename.concat (Filename.concat "merlint" "test") "cram";
  ]
  |> List.find_opt path_exists
  |> Option.value ~default:(Filename.concat (Filename.concat "test" "cram") "")

let fixture_dir rule = Filename.concat (cram_root ()) (rule_code rule ^ ".t")
let fixture_file rule name = Filename.concat (fixture_dir rule) name

let top_level_entries dir =
  try
    Sys.readdir dir |> Array.to_list
    |> List.map (Filename.concat dir)
    |> List.sort String.compare
  with Sys_error _ -> []

let basename_no_ext path = Filename.basename path |> Filename.remove_extension

let is_bad_fixture path =
  let name = basename_no_ext path in
  name = "bad" || String.starts_with ~prefix:"bad" name || name = "test_bad"

let is_good_fixture path =
  let name = basename_no_ext path in
  name = "good" || String.starts_with ~prefix:"good" name || name = "test_good"

let fixture_paths rule pred =
  let dir = fixture_dir rule in
  top_level_entries dir
  |> List.filter (fun path ->
      pred path
      && (Sys.is_directory path
         || Filename.check_suffix path ".ml"
         || Filename.check_suffix path ".mli"))

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

let check_fixture_inventory rule =
  Alcotest.(check bool)
    "bad fixtures exist" true
    (fixture_paths rule is_bad_fixture <> []);
  Alcotest.(check bool)
    "good fixtures exist" true
    (fixture_paths rule is_good_fixture <> [])

let fixture_suite rule =
  let code = rule_code rule in
  ( code,
    [
      Alcotest.test_case "metadata is complete" `Quick (fun () ->
          check_rule_metadata rule);
      Alcotest.test_case "cram fixtures exist" `Quick (fun () ->
          check_fixture_inventory rule);
    ] )
