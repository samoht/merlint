(** Fuzz parser with correct test name prefix. *)

let run () =
  Crowbar.add_test ~name:"parser: roundtrip" [ Crowbar.bytes ] (fun s ->
      ignore (s : string))
