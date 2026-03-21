(** Fuzz runner that properly includes all modules. *)

let () = Alcobar.run "parser" [ Fuzz_parser.suite ]
