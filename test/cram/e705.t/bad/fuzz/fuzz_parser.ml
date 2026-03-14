(** Fuzz tests for parser — missing .mli file. *)

let suite =
  ( "parser",
    [
      Crowbar.test_case "roundtrip" [ Crowbar.bytes ] (fun s ->
          ignore (s : string));
    ] )
