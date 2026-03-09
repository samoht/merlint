(** Fuzz parser with wrong suite name. *)

let suite =
  ( "wrong_name",
    [
      Crowbar.test_case "roundtrip" [ Crowbar.bytes ] (fun s ->
          ignore (s : string));
    ] )
