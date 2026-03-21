open Alcobar

let test_parse buf = ignore buf

let suite =
  ( "codec",
    Alcobar.[ test_case "parse crash safety" [ bytes ] test_parse ] )
