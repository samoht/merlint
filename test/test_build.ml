open Merlint

(* Tests for the Build helpers (dune build @check / cmt refresh).
   The shell-out paths need an Eio process_mgr and a real dune-project on
   disk; integration coverage lives in the cram suite. What is pinned here is
   the classification every typedtree-backed rule reads before it decides
   whether a file can be analysed at all. *)

let rec rm_rf path =
  match Unix.lstat path with
  | exception _ -> ()
  | { Unix.st_kind = Unix.S_DIR; _ } ->
      Sys.readdir path |> Array.iter (fun n -> rm_rf (Filename.concat path n));
      Unix.rmdir path
  | _ -> Sys.remove path

let with_temp_dir f =
  let dir = Filename.temp_file "merlint-build" "" in
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

let copy src dst =
  mkdir_p (Filename.dirname dst);
  let ic = open_in_bin src in
  Fun.protect ~finally:(fun () -> close_in ic) @@ fun () ->
  let contents = really_input_string ic (in_channel_length ic) in
  let oc = open_out_bin dst in
  Fun.protect
    ~finally:(fun () -> close_out oc)
    (fun () -> output_string oc contents)

(* A one-library dune project holding [lib/foo.ml], with the [.cmt] compiling it
   produces laid out where dune lays it out. [ocamlc] is expected to agree with
   [expect_failure] about the source, so a fixture that stops demonstrating what
   it was written for fails loudly rather than testing the other case. *)
let project ~expect_failure root contents =
  let source = Filename.concat root "lib/foo.ml" in
  write (Filename.concat root "dune-project") "(lang dune 3.0)\n";
  write (Filename.concat root "lib/dune") "(library (name foo))\n";
  write source contents;
  let status =
    Fmt.kstr Sys.command "cd %s && ocamlc -bin-annot -c lib/foo.ml 2>/dev/null"
      (Filename.quote root)
  in
  if expect_failure && status = 0 then
    Alcotest.failf "ocamlc accepted source that must not compile";
  if (not expect_failure) && status <> 0 then
    Alcotest.failf "ocamlc failed with status %d" status;
  let built = Filename.concat root "lib/foo.cmt" in
  if not (Sys.file_exists built) then
    Alcotest.failf "ocamlc wrote no .cmt for %s" source;
  copy built (Filename.concat root "_build/default/lib/.foo.objs/byte/foo.cmt");
  Fpath.v source

let status_of root file =
  Eio_main.run @@ fun env ->
  let index =
    Project_index.build ~installed:Project_index.Skip ~fs:(Eio.Stdenv.fs env)
      ~monorepo:(Fpath.v root) ()
  in
  Build.source_status ~root ~index file

let status =
  Alcotest.testable
    (fun ppf -> function
      | Build.Compiled -> Fmt.string ppf "Compiled"
      | Build.Not_compiled -> Fmt.string ppf "Not_compiled"
      | Build.Uncompilable -> Fmt.string ppf "Uncompilable"
      | Build.Skipped -> Fmt.string ppf "Skipped"
      | Build.Missing -> Fmt.string ppf "Missing")
    ( = )

let good = "let describe s = String.length s\n"

(* Uses [String] before the type error and [Buffer] after it: the artefact the
   compiler leaves behind records the first and not the second. *)
let bad =
  "let before s = String.length s\n\
   let broken : int = \"not an int\"\n\
   let after b = Buffer.contents b\n"

let test_compiled_source () =
  with_temp_dir @@ fun root ->
  let file = project ~expect_failure:false root good in
  Alcotest.check status "a built source is compiled" Build.Compiled
    (status_of root file)

let test_source_with_no_artefact () =
  with_temp_dir @@ fun root ->
  let file = project ~expect_failure:false root good in
  rm_rf (Filename.concat root "_build");
  Alcotest.check status "an unbuilt source is not compiled" Build.Not_compiled
    (status_of root file)

let test_missing_source () =
  with_temp_dir @@ fun root ->
  let _ = project ~expect_failure:false root good in
  Alcotest.check status "a source that does not exist is missing" Build.Missing
    (status_of root (Fpath.v (Filename.concat root "lib/nowhere.ml")))

(* The classification this test exists for. A compilation that FAILS still
   leaves a [.cmt]: the part of the unit the compiler typed before the error,
   stamped with the digest of the whole source. Calling that file compiled hands
   every typedtree-backed rule a tree that stops at the error line and reports
   the run as complete, so the rules answer about code they never saw -- E956
   reads the truncated import list and calls libraries the file uses further
   down dead. It is not compiled, and it is not merely unbuilt either: no build
   will produce an artefact for it while the source stands, so the run has to
   say the source does not compile rather than send the user to [dune build]. *)
let test_source_that_does_not_compile () =
  with_temp_dir @@ fun root ->
  let file = project ~expect_failure:true root bad in
  Alcotest.check status "a source the compiler refused is uncompilable"
    Build.Uncompilable (status_of root file)

let suite =
  ( "build",
    [
      Alcotest.test_case "a built source is compiled" `Quick
        test_compiled_source;
      Alcotest.test_case "a source with no artefact is not compiled" `Quick
        test_source_with_no_artefact;
      Alcotest.test_case "a source that does not exist is missing" `Quick
        test_missing_source;
      Alcotest.test_case "a source that does not compile is uncompilable" `Quick
        test_source_that_does_not_compile;
    ] )
