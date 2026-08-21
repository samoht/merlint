(** Spec for {!Merlint.Suite.missing_references}: an unresolved runner answers
    no absence claims. Reading "cannot see the references" as "references
    nothing" made E615 flag every test module whenever the runner's typedtree
    was stale -- for example mid-build under a concurrent dune. *)

let empty_implementation =
  `Implementation
    {
      Ocaml_typing.Typedtree.str_items = [];
      str_type = [];
      str_final_env = Ocaml_typing.Env.empty;
    }

let with_eio f = Eio_main.run @@ fun _env -> f ()

let unresolved_answers_no_absence () =
  with_eio @@ fun () ->
  let view =
    Merlint.File_view.v ~filename:"test.ml"
      ~content:(lazy "")
      ~typedtree:(fun () -> Ok None)
      ()
  in
  Alcotest.(check (list string))
    "no typedtree, no claims" []
    (Merlint.Suite.missing_references view [ "Test_foo"; "Test_bar" ])

let an_empty_runner_misses_everything () =
  with_eio @@ fun () ->
  let view =
    Merlint.File_view.v ~filename:"test.ml"
      ~content:(lazy "")
      ~typedtree:(fun () -> Ok (Some (empty_implementation, Merlin.Recorded)))
      ()
  in
  Alcotest.(check (list string))
    "resolved and silent: all missing" [ "Test_foo"; "Test_bar" ]
    (Merlint.Suite.missing_references view [ "Test_foo"; "Test_bar" ])

let suite =
  ( "suite",
    [
      Alcotest.test_case "unresolved answers no absence" `Quick
        unresolved_answers_no_absence;
      Alcotest.test_case "an empty runner misses everything" `Quick
        an_empty_runner_misses_everything;
    ] )
