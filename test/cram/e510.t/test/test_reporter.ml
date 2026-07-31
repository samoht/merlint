(* A test that exercises a reporter has to emit through it: the record is what
   the assertion reads. Declaring a source here would change that record, so
   the rule must not ask for one. *)
let test_reporter_emits () =
  Logs.set_reporter (Logs_fmt.reporter ());
  Logs.app (fun m -> m "hello")
