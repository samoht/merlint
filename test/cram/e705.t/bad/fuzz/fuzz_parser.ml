(** Fuzz tests for parser — missing .mli file. *)

let suite =
  ( "parser",
    [
      Alcobar.test_case "roundtrip" [ Alcobar.bytes ] (fun s ->
          ignore (s : string));
    ] )
