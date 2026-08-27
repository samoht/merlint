open Merlint

let test_run_empty_filter () =
  (* Test running with all rules disabled using "none" keyword *)
  match Filter.parse "none" with
  | Error msg -> Alcotest.failf "Failed to create filter: %s" msg
  | Ok filter ->
      Eio_main.run @@ fun env ->
      let fs = Eio.Stdenv.fs env in
      let index ?pool () =
        ignore pool;
        Project_index.build ~fs ~monorepo:(Fpath.v ".") ()
      in
      let result =
        Engine.run
          ~load_file:(fun f -> In_channel.with_open_text f In_channel.input_all)
          ~filter ~index "."
      in
      Alcotest.(check int)
        "no results with all rules disabled" 0
        (List.length result.Engine.issues)

(* {2 File accounting} *)

let rec rm_rf path =
  match Unix.lstat path with
  | exception _ -> ()
  | { Unix.st_kind = Unix.S_DIR; _ } ->
      Sys.readdir path |> Array.iter (fun n -> rm_rf (Filename.concat path n));
      Unix.rmdir path
  | _ -> Sys.remove path

let with_temp_dir f =
  let dir = Filename.temp_file "merlint-engine" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  Fun.protect ~finally:(fun () -> rm_rf dir) (fun () -> f dir)

let mkdir_p path =
  let rec loop path =
    if Sys.file_exists path then ()
    else begin
      loop (Filename.dirname path);
      Unix.mkdir path 0o755
    end
  in
  loop path

let write path contents =
  mkdir_p (Filename.dirname path);
  let oc = open_out path in
  Fun.protect
    ~finally:(fun () -> close_out oc)
    (fun () -> output_string oc contents)

let read_file f = In_channel.with_open_text f In_channel.input_all

(* One run over [root]. [spec] defaults to every rule disabled, which is what
   the file-accounting cases want: no rule reading an artefact means nothing
   lands in [unchecked_files] for the unrelated reason that this fixture was
   never built. [load_file] is what the rules read a source through. *)
let run_on ?(spec = "none") ?(load_file = read_file) ?analyze_set root =
  match Filter.parse spec with
  | Error msg -> Alcotest.failf "Failed to create filter: %s" msg
  | Ok filter ->
      Eio_main.run @@ fun env ->
      let fs = Eio.Stdenv.fs env in
      let index ?pool () =
        ignore pool;
        Project_index.build ~installed:Project_index.Skip ?pool ~fs
          ~monorepo:(Fpath.v root) ()
      in
      Engine.run ~load_file ~filter ?analyze_set ~index root

(* A two-package source root whose [fuzz/] holds a private executable: the shape
   every fuzz and bench directory in a multi-package repository has. Dune
   compiles all three modules, so all three are the engine's to analyse. *)
let fuzz_shape_project root =
  write
    (Filename.concat root "dune-project")
    "(lang dune 3.21)\n\
     (generate_opam_files true)\n\
     (package (name alpha))\n\
     (package (name alpha-eio))\n";
  write (Filename.concat root "alpha.opam") "opam-version: \"2.0\"\n";
  write (Filename.concat root "alpha-eio.opam") "opam-version: \"2.0\"\n";
  write
    (Filename.concat root "lib/dune")
    "(library (name alpha) (public_name alpha))\n";
  write (Filename.concat root "lib/alpha.ml") "let x = 1\n";
  write
    (Filename.concat root "fuzz/dune")
    "(executable\n\
    \ (name fuzz)\n\
    \ (libraries alpha))\n\n\
     (rule\n\
    \ (alias runtest)\n\
    \ (package alpha)\n\
    \ (deps fuzz.exe)\n\
    \ (action\n\
    \  (run %{exe:fuzz.exe})))\n";
  write (Filename.concat root "fuzz/fuzz.ml") "let () = ()\n";
  write (Filename.concat root "fuzz/fuzz_alpha.ml") "let y = 2\n";
  write (Filename.concat root "fuzz/fuzz_alpha.mli") "val y : int\n"

(* A file the engine never analyses is a file the run says nothing about, and a
   verdict that reports "all checks passed" over sources it never opened is
   wrong however few they are. The engine must iterate every source dune
   compiles -- here the private executable's three modules alongside the
   library's one. *)
let test_analyses_package_less_private_executable () =
  with_temp_dir (fun root ->
      fuzz_shape_project root;
      let result = run_on root in
      Alcotest.(check int)
        "library module and all three private-executable modules" 4
        result.Engine.files_analyzed)

(* Every [.ml] / [.mli] under the scanned path is either analysed or named as
   unclaimed. A file in neither half is one the run says nothing about while
   reporting its verdict as the verdict of the directory, which is the failure
   the accounting exists to make impossible: whatever the cause -- a stanza shape
   discovery cannot attribute, a [(modules ...)] spec excluding a sibling, a
   directory holding no dune file at all -- the numbers stop adding up and say
   so. Here two files are claimed by nothing: [snippets/] has no dune file, and
   [lib/shared.ml] is outside the library's [(modules ...)] spec. *)
let test_accounts_for_every_source_file () =
  with_temp_dir (fun root ->
      fuzz_shape_project root;
      write (Filename.concat root "snippets/example.ml") "let z = 3\n";
      write (Filename.concat root "lib/shared.ml") "let s = 4\n";
      write
        (Filename.concat root "lib/dune")
        "(library (name alpha) (public_name alpha) (modules alpha))\n";
      let result = run_on root in
      let on_disk = 6 in
      Alcotest.(check int)
        "analysed plus unclaimed accounts for every source file" on_disk
        (result.Engine.files_analyzed
        + List.length result.Engine.unclaimed_files);
      Alcotest.(check (list string))
        "and the unclaimed half names them"
        [ "lib/shared.ml"; "snippets/example.ml" ]
        (result.Engine.unclaimed_files
        |> List.filter_map (fun f ->
            Fpath.rem_prefix (Fpath.v root) (Fpath.v f))
        |> List.map Fpath.to_string |> List.sort String.compare))

(* A check that raises returns the empty list, which is exactly what a check that
   ran and found nothing returns, so the two are told apart by the failure set or
   not at all. The same fixture is run twice with the same rules, and what raises
   the second time is a source the process may not open -- a condition merlint
   does not create and cannot pre-empt, so this stays a test of the accounting
   rather than of whichever traversal happens to overflow today. *)
let test_records_a_check_that_raised () =
  with_temp_dir (fun root ->
      fuzz_shape_project root;
      let source = Filename.concat root "lib/alpha.ml" in
      (* One file, so [rules_applied] -- a union of codes over the whole run --
         answers for that file rather than for whatever its siblings still
         managed. *)
      let run () = run_on ~spec:"all" ~analyze_set:[ Fpath.v source ] root in
      let clean = run () in
      Alcotest.(check int)
        "a run that read every source it was given has nothing to report" 0
        (List.length clean.Engine.failed);
      Unix.chmod source 0o000;
      let result =
        Fun.protect ~finally:(fun () -> Unix.chmod source 0o644) run
      in
      Alcotest.(check bool)
        "a run that could not open one reports it" true
        (result.Engine.failed <> []);
      Alcotest.(check bool)
        "every failure names the exception and the file it was reading" true
        (List.for_all
           (fun (f : Engine.failure) -> f.error <> "" && f.file <> None)
           result.Engine.failed);
      Alcotest.(check bool)
        "and a check that raised is not counted as applied" true
        (result.Engine.rules_applied < clean.Engine.rules_applied))

(* A file named on the command line that no dune stanza claims. The run has one
   file to look at and no stanza to place it in, so no rule that needs one ran
   on it and the verdict answers for nothing. Naming the file is what the caller
   asked about, which is the whole difference from a directory's orphans. *)
let test_names_an_unclaimed_file_given_explicitly () =
  with_temp_dir (fun root ->
      fuzz_shape_project root;
      write (Filename.concat root "lib/shared.ml") "let s = 4\n";
      write
        (Filename.concat root "lib/dune")
        "(library (name alpha) (public_name alpha) (modules alpha))\n";
      let relative result =
        result.Engine.unclaimed_files
        |> List.filter_map (fun f ->
            Fpath.rem_prefix (Fpath.v root) (Fpath.v f))
        |> List.map Fpath.to_string |> List.sort String.compare
      in
      let orphan = Fpath.v (Filename.concat root "lib/shared.ml") in
      Alcotest.(check (list string))
        "the file the caller named, and only it" [ "lib/shared.ml" ]
        (relative (run_on ~analyze_set:[ orphan ] root));
      let claimed = Fpath.v (Filename.concat root "lib/alpha.ml") in
      Alcotest.(check (list string))
        "a named file a stanza does claim leaves the set empty" []
        (relative (run_on ~analyze_set:[ claimed ] root)))

let suite =
  ( "engine",
    [
      Alcotest.test_case "run with empty filter" `Quick test_run_empty_filter;
      Alcotest.test_case "analyses a package-less private executable" `Quick
        test_analyses_package_less_private_executable;
      Alcotest.test_case "accounts for every source file" `Quick
        test_accounts_for_every_source_file;
      Alcotest.test_case "records a check that raised" `Quick
        test_records_a_check_that_raised;
      Alcotest.test_case "names an unclaimed file given explicitly" `Quick
        test_names_an_unclaimed_file_given_explicitly;
    ] )
