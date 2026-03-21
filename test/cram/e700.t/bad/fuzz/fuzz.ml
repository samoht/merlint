(** Fuzz runner that defines tests inline instead of delegating. *)


let () = Alcobar.run "crowbar" [
  Alcobar.test_case "parse" [ Alcobar.bytes ] (fun s ->
      ignore (s : string))
]
