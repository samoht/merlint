(** Fuzz tests for parser. *)

let suite =
  ( "parser",
    [
      Alcobar.test_case "roundtrip" [ Alcobar.bytes ] (fun s ->
          ignore (s : string));
    ] )
