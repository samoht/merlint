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
    ("run nonexistent", `Quick, test_run_nonexistent);
  ]

let suite = ("command", tests)
