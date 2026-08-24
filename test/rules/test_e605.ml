open Merlint

let rec rm_rf path =
  match Unix.lstat path with
  | exception _ -> ()
  | { Unix.st_kind = Unix.S_DIR; _ } ->
      Sys.readdir path |> Array.iter (fun n -> rm_rf (Filename.concat path n));
      Unix.rmdir path
  | _ -> Sys.remove path

let with_temp_dir f =
  let dir = Filename.temp_file "merlint-e605" "" in
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

let run_e605 root =
  match Filter.parse "E605" with
  | Error msg -> Alcotest.failf "Failed to create filter: %s" msg
  | Ok filter ->
      let result =
        Eio_main.run @@ fun env ->
        let fs = Eio.Stdenv.fs env in
        let index ?pool () =
          Project_index.build ~installed:Project_index.Skip ?pool ~fs
            ~monorepo:(Fpath.v root) ()
        in
        Engine.run
          ~load_file:(fun f -> In_channel.with_open_text f In_channel.input_all)
          ~filter ~index root
      in
      result.Engine.issues |> List.map Rule.Run.message
      |> List.sort String.compare

(* A [(select target from (cond -> branch.ml) ...)] branch compiles under
   [target]'s name and never its own: [pick.unix.ml] is one possible body of
   [Pick], and [pick.unix] is no module name at all -- a dot cannot appear in
   one. So the untested unit here is [pick], named once however many branches
   the select carries, and the test it wants is [test/test_pick.ml].

   Reading the name off the branch's own basename instead asks for
   [test_pick.unix.ml] and [test_pick.plain.ml], two files no build could
   compile as tests of anything, and reports one gap twice. That is what this
   test refuses. *)
let test_select_branch_named_by_its_target () =
  with_temp_dir (fun root ->
      write
        (Filename.concat root "dune-project")
        "(lang dune 3.21)\n(generate_opam_files true)\n(package (name sel))\n";
      write (Filename.concat root "sel.opam") "opam-version: \"2.0\"\n";
      write
        (Filename.concat root "lib/dune")
        "(library\n\
        \ (name sel)\n\
        \ (public_name sel)\n\
        \ (libraries\n\
        \  (select pick.ml from (unix -> pick.unix.ml) (-> pick.plain.ml))))\n";
      write (Filename.concat root "lib/sel.ml") "let x = 1\n";
      write (Filename.concat root "lib/pick.unix.ml") "let which = 1\n";
      write (Filename.concat root "lib/pick.plain.ml") "let which = 0\n";
      write
        (Filename.concat root "test/dune")
        "(test (name test_sel) (libraries sel))\n";
      write (Filename.concat root "test/test_sel.ml") "let () = ()\n";
      Alcotest.(check (list string))
        "the select's branches are one untested module, named by the target"
        [
          Fmt.str
            "Module 'pick' has no tests yet — write thoughtful, adversarial \
             tests against it. Expected file: %s/test/test_pick.ml"
            root;
        ]
        (run_e605 root))

let suite =
  let name, cases = Test_helpers.fixture_suite Merlint.E605.rule in
  ( name,
    cases
    @ [
        Alcotest.test_case "a select branch is named by its target" `Quick
          test_select_branch_named_by_its_target;
      ] )
