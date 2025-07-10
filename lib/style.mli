(** Code style rules

    This module enforces code style rules such as avoiding Obj.magic and
    catch-all exception handlers. *)

val check : filename:string -> Parsetree.t -> Issue.t list
(** [check ~filename parsetree] analyzes the parsetree for style issues. *)

val extract_location_from_parsetree : string -> (int * int) option
(** [extract_location_from_parsetree text] extracts line and column from
    parsetree text *)

val extract_filename_from_parsetree : string -> string
(** [extract_filename_from_parsetree text] extracts filename from parsetree text
*)
