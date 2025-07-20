(* Test for utils module *)

let test_string_of_list () =
  let result = Myproject.Utils.string_of_list string_of_int [1; 2; 3] in
  assert (result = "[1; 2; 3]")

let test_option_map () =
  let result = Myproject.Utils.option_map (fun x -> x + 1) (Some 41) in
  assert (result = Some 42)

let () =
  test_string_of_list ();
  test_option_map ();
  print_endline "Utils tests passed"