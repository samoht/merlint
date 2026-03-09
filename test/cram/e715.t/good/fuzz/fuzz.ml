(** Fuzz runner that properly includes all modules. *)

let () = Crowbar.run "parser" [ Fuzz_parser.suite ]
