(** Naming convention rules

    This module checks that OCaml code follows modern naming conventions. *)

val check : filename:string -> outline:Yojson.Safe.t option -> Yojson.Safe.t -> Issue.t list
(** [check ~filename ~outline ast] analyzes the AST and returns naming issues. 
    If outline is provided, it will be used for function naming checks. *)
