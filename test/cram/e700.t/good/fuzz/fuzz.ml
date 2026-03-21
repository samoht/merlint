(** Fuzz runner that properly delegates to modules. *)

let () = Alcobar.run "parser" [ Fuzz_parser.suite ]
