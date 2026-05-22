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

let rec mkdir_p path =
  if Sys.file_exists path then ()
  else begin
    mkdir_p (Filename.dirname path);
    Unix.mkdir path 0o700
  end

let test_script_contains () =
  with_temp_dir "merlint-interop-" @@ fun root ->
  write_file
    (Filename.concat root "setup.sh")
    "pip install --break-system-packages\n";
  write_file (Filename.concat root "notes.txt") "--break-system-packages\n";
  Alcotest.(check bool)
    "script hit" true
    (Merlint.Interop.script_contains ~dir:root ~file:"setup.sh"
       ~affix:"--break-system-packages");
  Alcotest.(check bool)
    "non-script ignored" false
    (Merlint.Interop.script_contains ~dir:root ~file:"notes.txt"
       ~affix:"--break-system-packages");
  Alcotest.(check bool)
    "missing ignored" false
    (Merlint.Interop.script_contains ~dir:root ~file:"missing.sh"
       ~affix:"--break-system-packages")

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

let test_oracle_dirs_exclude_vendored_packages () =
  with_temp_dir "merlint-interop-" @@ fun root ->
  write_file (Filename.concat root "dune-project") "(lang dune 3.0)\n";
  write_file (Filename.concat root "dune") "(vendored_dirs vendor)\n";
  let oracle_dir package_dir tool =
    let dir = Filename.concat package_dir ("test/interop/" ^ tool) in
    mkdir_p dir;
    mkdir_p (Filename.concat dir "scripts");
    mkdir_p (Filename.concat dir "traces");
    write_file (Filename.concat dir "dune") "(test (name test))\n";
    write_file (Filename.concat dir "test.ml") "let () = ()\n"
  in
  let pkg = Filename.concat root "pkg" in
  mkdir_p pkg;
  write_file (Filename.concat pkg "pkg.opam") "opam-version: \"2.0\"\n";
  oracle_dir pkg "opa";
  let vendored = Filename.concat root "vendor/vpkg" in
  mkdir_p vendored;
  write_file (Filename.concat vendored "vpkg.opam") "opam-version: \"2.0\"\n";
  oracle_dir vendored "hidden";
  let index =
    Eio_main.run @@ fun env ->
    let fs = Eio.Stdenv.fs env in
    Project_index.build ~fs ~monorepo:(Fpath.v root) ()
  in
  match Merlint.Interop.oracle_dirs index with
  | [ dir ] ->
      Alcotest.(check string) "package" "pkg" dir.package;
      Alcotest.(check string) "tool" "opa" dir.tool
  | dirs ->
      Alcotest.failf "expected one non-vendored oracle dir, got %d"
        (List.length dirs)

let suite =
  ( "interop",
    [
      Alcotest.test_case "script text query" `Quick test_script_contains;
      Alcotest.test_case "oracle discovery" `Quick test_oracle_dirs;
      Alcotest.test_case "oracle discovery excludes vendored packages" `Quick
        test_oracle_dirs_exclude_vendored_packages;
    ] )
