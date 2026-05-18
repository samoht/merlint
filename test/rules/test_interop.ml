let with_temp_dir name f =
  let root = Filename.temp_file name "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  let rec remove_tree path =
    if Sys.is_directory path then begin
      Sys.readdir path
      |> Array.iter (fun entry -> remove_tree (Filename.concat path entry));
      Unix.rmdir path
    end
    else Sys.remove path
  in
  Fun.protect ~finally:(fun () -> remove_tree root) (fun () -> f root)

let write_file path content =
  let oc = open_out path in
  Fun.protect
    ~finally:(fun () -> close_out oc)
    (fun () -> output_string oc content)

let mkdir path = if not (Sys.file_exists path) then Unix.mkdir path 0o700

let test_file_helpers () =
  with_temp_dir "merlint-interop-" @@ fun root ->
  let dune = Filename.concat root "dune" in
  let test_ml = Filename.concat root "test.ml" in
  write_file dune "(test (name test))\n";
  write_file test_ml "let () = ()\n";
  Alcotest.(check string)
    "read_file existing" "(test (name test))\n"
    (Merlint.Interop.read_file dune);
  Alcotest.(check string)
    "read_file missing" ""
    (Merlint.Interop.read_file (Filename.concat root "x"));
  Alcotest.(check string)
    "dune_content" "(test (name test))\n"
    (Merlint.Interop.dune_content root);
  Alcotest.(check string)
    "test_content" "let () = ()\n"
    (Merlint.Interop.test_content root)

let test_oracle_dirs () =
  with_temp_dir "merlint-interop-" @@ fun root ->
  let pkg = Filename.concat root "pkg" in
  let test = Filename.concat pkg "test" in
  let interop = Filename.concat test "interop" in
  let tool = Filename.concat interop "opa" in
  List.iter mkdir [ pkg; test; interop; tool ];
  mkdir (Filename.concat tool "scripts");
  mkdir (Filename.concat tool "traces");
  write_file (Filename.concat tool "dune") "(test (name test))\n";
  write_file (Filename.concat tool "test.ml") "let () = ()\n";
  write_file (Filename.concat pkg "pkg.opam") "opam-version: \"2.0\"\n";
  write_file (Filename.concat root "dune-project") "(lang dune 3.0)\n";
  let index =
    Eio_main.run @@ fun env ->
    let fs = Eio.Stdenv.fs env in
    Project_index.build ~fs ~monorepo:(Fpath.v root) ()
  in
  match Merlint.Interop.oracle_dirs index with
  | [ dir ] ->
      Alcotest.(check string) "package" "pkg" dir.package;
      Alcotest.(check string) "tool" "opa" dir.tool;
      Alcotest.(check bool) "has scripts" true dir.has_scripts;
      Alcotest.(check bool) "has traces" true dir.has_traces;
      Alcotest.(check bool) "has dune" true dir.has_dune;
      Alcotest.(check bool) "has test.ml" true dir.has_test_ml
  | dirs -> Alcotest.failf "expected one oracle dir, got %d" (List.length dirs)

let suite =
  ( "interop",
    [
      Alcotest.test_case "file helpers" `Quick test_file_helpers;
      Alcotest.test_case "oracle discovery" `Quick test_oracle_dirs;
    ] )
