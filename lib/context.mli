(** Context for rule checking - holds all parameters and data needed by rules.
*)

exception Analysis_error of string
(** Raised when analysis fails (e.g., Merlin error, file read error). *)

type file = {
  filename : string;  (** The current file being analyzed. *)
  config : Config.t;  (** The merlint configuration. *)
  project_root : string;  (** The project root directory. *)
  ast : Ast.t Lazy.t;  (** AST control flow from ppxlib (lazy). *)
  dump : Dump.t Lazy.t;  (** Names/identifiers from Merlin dump (lazy). *)
  outline : Outline.t Lazy.t;  (** Outline from Merlin (lazy). *)
  content : string Lazy.t;  (** File content (lazy). *)
  functions : (string * Ast.expr) list Lazy.t;
      (** Functions extracted with ppxlib (lazy). *)
}

type project = {
  config : Config.t;  (** The merlint configuration. *)
  project_root : string;  (** The project root directory. *)
  all_files : string list Lazy.t;  (** All files in the project (lazy). *)
  dune_describe : Dune.describe Lazy.t;  (** Dune project description (lazy). *)
  executable_modules : string list Lazy.t;
      (** List of executable module names (lazy). *)
  lib_modules : string list Lazy.t;  (** List of library module names (lazy). *)
  test_modules : string list Lazy.t;  (** List of test module names (lazy). *)
}

val file :
  filename:string ->
  config:Config.t ->
  project_root:string ->
  merlin_result:Merlin.t ->
  file
(** [file ~filename ~config ~project_root ~merlin_result] creates a file
    context. *)

val project :
  config:Config.t ->
  project_root:string ->
  all_files:string list ->
  dune_describe:Dune.describe ->
  project
(** [project ~config ~project_root ~all_files ~dune_describe] creates a project
    context. *)

(** {2 File context accessors} *)

val ast : file -> Ast.t
(** [ast file] returns ast field. *)

val dump : file -> Dump.t
(** [dump file] returns dump field. *)

val outline : file -> Outline.t
(** [outline file] returns outline field. *)

val content : file -> string
(** [content file] returns content field. *)

val functions : file -> (string * Ast.expr) list
(** [functions file] returns functions field. *)

(** {2 Project context accessors} *)

val all_files : project -> string list
(** [all_files project] returns all files. *)

val executable_modules : project -> string list
(** [executable_modules project] returns executable module names. *)

val lib_modules : project -> string list
(** [lib_modules project] returns library module names. *)

val test_modules : project -> string list
(** [test_modules project] returns test module names. *)

val dune_describe : project -> Dune.describe
(** [dune_describe project] returns the dune project description. *)
