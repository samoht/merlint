(** E500: Missing OCamlformat File

    This rule ensures that projects have a .ocamlformat file for consistent
    formatting. All OCaml projects should have a .ocamlformat file in the root
    directory. *)

val check : Context.project -> Issue.t list
(** [check project_root] checks if the project root has a .ocamlformat file.
    Returns a list of issues if the file is missing. *)
