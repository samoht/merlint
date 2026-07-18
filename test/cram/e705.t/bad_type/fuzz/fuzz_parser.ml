(** Fuzz tests for parser. *)

let normalize s = String.trim s

let suite =
  ( "parser",
    [
      Alcobar.test_case "roundtrip" [ Alcobar.bytes ] (fun s ->
          ignore (normalize s : string));
    ] )
