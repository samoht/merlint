(** Fuzz parser with wrong test name prefix. *)

let run () =
  Crowbar.add_test ~name:"wrong prefix" [ Crowbar.bytes ] (fun s ->
      ignore (s : string))
