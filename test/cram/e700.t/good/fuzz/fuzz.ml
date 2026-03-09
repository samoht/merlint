(** Fuzz runner that properly delegates to modules. *)

let () = Crowbar.run "parser" [ Fuzz_parser.suite ]
