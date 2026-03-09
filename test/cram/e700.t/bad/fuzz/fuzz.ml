(** Fuzz runner that defines tests inline instead of delegating. *)


let () = Crowbar.run "crowbar" [
  Crowbar.test_case "parse" [ Crowbar.bytes ] (fun s ->
      ignore (s : string))
]
