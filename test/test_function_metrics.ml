let empty_structure =
  {
    Ocaml_typing.Typedtree.str_items = [];
    str_type = [];
    str_final_env = Ocaml_typing.Env.empty;
  }

let test_empty_structure_no_values () =
  Alcotest.(check int)
    "no values" 0
    (List.length (Merlint.Function_metrics.of_structure empty_structure))

let test_empty_view_exposes_metrics () =
  let view =
    Merlint.File_view.v ~filename:"empty.ml"
      ~typedtree:(fun () -> Ok (Some (`Implementation empty_structure)))
      ()
  in
  Alcotest.(check int)
    "no values through file view" 0
    (List.length (Merlint.File_view.values view))

let tests =
  [
    ("empty_structure_has_no_values", `Quick, test_empty_structure_no_values);
    ("empty_view_exposes_no_metrics", `Quick, test_empty_view_exposes_metrics);
  ]

let suite = ("function_metrics", tests)
