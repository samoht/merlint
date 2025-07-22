(** Tests for Command module *)

let test_run_success () =
  (* Test running a simple command *)
  match Merlint.Command.run "echo test" with
  | Ok output ->
      Alcotest.(check bool)
        "output contains test" true
        (String.contains output 't')
  | Error msg -> Alcotest.fail ("Expected success but got error: " ^ msg)

let test_run_failure () =
  (* Test running a command that fails *)
  match Merlint.Command.run "false" with
  | Ok _ -> Alcotest.fail "Expected error but got success"
  | Error _ -> ()

let test_run_nonexistent () =
  (* Test running a nonexistent command *)
  match Merlint.Command.run "nonexistent_command_12345" with
  | Ok _ -> Alcotest.fail "Expected error but got success"
  | Error _ -> ()

let tests =
  [
    ("run success", `Quick, test_run_success);
    ("run failure", `Quick, test_run_failure);
    ("run nonexistent", `Quick, test_run_nonexistent);
  ]

let suite = ("command", tests)
