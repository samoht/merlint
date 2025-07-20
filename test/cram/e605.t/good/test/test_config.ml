(* Test for config module *)

let test_default_config () =
  let config = Myproject.Config.default in
  assert (not config.debug);
  assert (not config.verbose);
  assert (config.max_iterations = 100)

let test_from_env () =
  (* Test without DEBUG env var *)
  let config = Myproject.Config.from_env () in
  assert (not config.debug)

let () =
  test_default_config ();
  test_from_env ();
  print_endline "Config tests passed"