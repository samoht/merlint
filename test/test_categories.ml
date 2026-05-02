open Merlint

let load_in_tmp ~contents =
  let dir = Filename.temp_file "categories_dir" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let path = Filename.concat dir "categories.toml" in
  let oc = open_out path in
  output_string oc contents;
  close_out oc;
  Fun.protect
    ~finally:(fun () ->
      Sys.remove path;
      Unix.rmdir dir)
    (fun () -> Categories.load dir)

let test_missing_file () =
  let dir = Filename.temp_file "categories_missing" "" in
  Sys.remove dir;
  Alcotest.(check (list string)) "absent file is empty" [] (Categories.load dir)

let test_top_level_headers () =
  let slugs = load_in_tmp ~contents:"[codec]\n[crypto]\n[network]\n" in
  Alcotest.(check (list string))
    "top-level headers extracted"
    [ "codec"; "crypto"; "network" ]
    slugs

let test_dotted_headers () =
  let slugs = load_in_tmp ~contents:"[codec]\n[codec.text]\n[codec.binary]\n" in
  Alcotest.(check (list string))
    "dotted headers preserved as-is"
    [ "codec"; "codec.text"; "codec.binary" ]
    slugs

let test_skips_keys () =
  let slugs = load_in_tmp ~contents:"[codec]\nname = \"x\"\n[crypto]\n" in
  Alcotest.(check (list string))
    "key/value lines are skipped" [ "codec"; "crypto" ] slugs

let test_skips_array_tables () =
  let slugs = load_in_tmp ~contents:"[codec]\n[[items]]\n[crypto]\n" in
  Alcotest.(check (list string))
    "array-table headers ([[ ... ]]) are skipped" [ "codec"; "crypto" ] slugs

let test_trims_whitespace () =
  let slugs = load_in_tmp ~contents:"   [codec]   \n[crypto]\n" in
  Alcotest.(check (list string))
    "leading/trailing whitespace around header is trimmed" [ "codec"; "crypto" ]
    slugs

let suite =
  ( "categories",
    [
      Alcotest.test_case "missing file -> empty" `Quick test_missing_file;
      Alcotest.test_case "top-level headers" `Quick test_top_level_headers;
      Alcotest.test_case "dotted headers" `Quick test_dotted_headers;
      Alcotest.test_case "skips key/value lines" `Quick test_skips_keys;
      Alcotest.test_case "skips array-table headers" `Quick
        test_skips_array_tables;
      Alcotest.test_case "trims whitespace" `Quick test_trims_whitespace;
    ] )
