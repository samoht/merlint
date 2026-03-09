(** Fuzz runner that defines tests inline instead of delegating. *)

let () =
  Crowbar.add_test ~name:"parse" [ Crowbar.bytes ] (fun s ->
      ignore (s : string))
