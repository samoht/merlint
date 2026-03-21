(** Fuzz parser with wrong suite name. *)

let suite =
  ( "wrong_name",
    [
      Alcobar.test_case "roundtrip" [ Alcobar.bytes ] (fun s ->
          ignore (s : string));
    ] )
