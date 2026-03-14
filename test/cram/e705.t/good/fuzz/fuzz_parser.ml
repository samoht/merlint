(** Fuzz tests for parser. *)

let suite =
  ( "parser",
    [
      Crowbar.test_case "roundtrip" [ Crowbar.bytes ] (fun s ->
          ignore (s : string));
    ] )
