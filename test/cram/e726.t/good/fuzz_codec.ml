open Crowbar

let test_parse buf = ignore buf

let suite =
  ( "codec",
    Crowbar.[ test_case "parse crash safety" [ bytes ] test_parse ] )
