(* Test for parser module *)

let test_tokenize () =
  let tokens = Myproject.Parser.tokenize "42 + 5" in
  assert (List.length tokens = 4)

let test_parse () =
  let tokens = Myproject.Parser.([ Int 42; Plus; Int 5; EOF ]) in
  let result = Myproject.Parser.parse tokens in
  assert (result = 47)

let () =
  test_tokenize ();
  test_parse ();
  print_endline "Parser tests passed"