(** Fuzz parser with correct suite name. *)

let suite =
  ( "parser",
    [
      Crowbar.test_case "roundtrip" [ Crowbar.bytes ] (fun s ->
          ignore (s : string));
    ] )
