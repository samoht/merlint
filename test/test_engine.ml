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

(* Run with every rule disabled: the file set the engine iterates is what is
   under test, and no rule reading an artefact means nothing lands in
   [unchecked_files] for the unrelated reason that this fixture was never
   built. *)
let run_on root =
  match Filter.parse "none" with
  | Error msg -> Alcotest.failf "Failed to create filter: %s" msg
  | Ok filter ->
      Eio_main.run @@ fun env ->
      let fs = Eio.Stdenv.fs env in
      let index ?pool () =
        ignore pool;
        Project_index.build ~installed:Project_index.Skip ?pool ~fs
          ~monorepo:(Fpath.v root) ()
      in
      Engine.run
        ~load_file:(fun f -> In_channel.with_open_text f In_channel.input_all)
        ~filter ~index root

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

let suite =
  ( "engine",
    [
      Alcotest.test_case "run with empty filter" `Quick test_run_empty_filter;
      Alcotest.test_case "analyses a package-less private executable" `Quick
        test_analyses_package_less_private_executable;
    ] )
