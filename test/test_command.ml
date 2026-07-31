(** Tests for Command module *)

let test_run_success () =
  Eio_main.run @@ fun env ->
  let mgr = Eio.Stdenv.process_mgr env in
  match Merlint.Command.run mgr "echo test" with
  | Ok output ->
      Alcotest.(check bool)
        "output contains test" true
        (String.contains output 't')
  | Error msg -> Alcotest.fail ("Expected success but got error: " ^ msg)

let test_run_failure () =
  Eio_main.run @@ fun env ->
  let mgr = Eio.Stdenv.process_mgr env in
  match Merlint.Command.run mgr "false" with
  | Ok _ -> Alcotest.fail "Expected error but got success"
  | Error _ -> ()

(* A failing command explains itself on stderr, and the caller needs that to
   act: dune reports both a busy daemon and broken code by exiting 1, and says
   which only there. An exit code alone cannot tell them apart. *)
let test_run_failure_carries_stderr () =
  Eio_main.run @@ fun env ->
  let mgr = Eio.Stdenv.process_mgr env in
  match Merlint.Command.run mgr "echo 'why it failed' >&2; exit 3" with
  | Ok _ -> Alcotest.fail "Expected error but got success"
  | Error msg ->
      let mentions needle =
        let n = String.length needle and m = String.length msg in
        let rec go i =
          i + n <= m && (String.sub msg i n = needle || go (i + 1))
        in
        go 0
      in
      Alcotest.(check bool) "names the exit code" true (mentions "exit code 3");
      Alcotest.(check bool)
        "and repeats what the command said" true (mentions "why it failed")

let test_run_nonexistent () =
  Eio_main.run @@ fun env ->
  let mgr = Eio.Stdenv.process_mgr env in
  match Merlint.Command.run mgr "nonexistent_command_12345" with
  | Ok _ -> Alcotest.fail "Expected error but got success"
  | Error _ -> ()

let tests =
  [
    ("run success", `Quick, test_run_success);
    ("run failure", `Quick, test_run_failure);
    ("run failure carries stderr", `Quick, test_run_failure_carries_stderr);
    ("run nonexistent", `Quick, test_run_nonexistent);
  ]

let suite = ("command", tests)
