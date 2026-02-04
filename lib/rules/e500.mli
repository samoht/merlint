(** E500: Missing OCamlformat File

    This rule ensures that projects have a .ocamlformat file for consistent
    formatting. All OCaml projects should have a .ocamlformat file in the root
    directory. *)

val rule : Rule.t
(** The E500 rule definition *)
