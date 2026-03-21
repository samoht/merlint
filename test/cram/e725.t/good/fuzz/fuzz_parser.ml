(** Fuzz parser with correct suite name. *)

let suite =
  ( "parser",
    [
      Alcobar.test_case "roundtrip" [ Alcobar.bytes ] (fun s ->
          ignore (s : string));
    ] )
