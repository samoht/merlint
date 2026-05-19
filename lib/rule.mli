(** Linting rule definitions and registry. *)

(** Rule categories. *)
type category =
  | Complexity
  | Security_safety
  | Style_modernization
  | Naming_conventions
  | Documentation
  | Project_structure
  | Testing
  | Interop_testing
  | Code_generation

type example = {
  is_good : bool;  (** true for good examples, false for bad examples. *)
  code : string;  (** The example code. *)
}
(** A code example with label. *)

type 'a scope =
  | File of (Context.file -> 'a Issue.t list)
  | Project of (Context.project -> 'a Issue.t list)
  | Project_units : {
      enumerate : Context.project -> 'unit list;
      check : Context.project -> 'unit -> 'a Issue.t list;
    }
      -> 'a scope
      (** Rule scope. [Project_units] is for the small set of project rules
          whose work naturally splits into independent units; the engine
          schedules those units directly. *)

type t
(** Type for rules. *)

val v :
  code:string ->
  title:string ->
  category:category ->
  hint:string ->
  ?examples:example list ->
  pp:'a Fmt.t ->
  'a scope ->
  t
(** [v ~code ~title ~category ~hint ?examples ~pp scope] creates a new rule. *)

val code : t -> string
(** [code rule] returns rule code. *)

val title : t -> string
(** [title rule] returns rule title. *)

val category : t -> category
(** [category rule] returns rule category. *)

val hint : t -> string
(** [hint rule] returns rule hint. *)

val examples : t -> example list
(** [examples rule] returns rule examples. *)

val category_name : category -> string
(** [category_name category] returns display name. *)

val is_file_scoped : t -> bool
(** [is_file_scoped rule] checks if file scoped. *)

val is_project_scoped : t -> bool
(** [is_project_scoped rule] checks if project scoped. *)

val pp : t Fmt.t
(** [pp] formats a rule for display. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are the same rule. *)

(** Module for handling rule execution results. *)
module Run : sig
  type result
  (** Result of running a rule, containing the issue and metadata. *)

  type project_job
  (** One schedulable project-rule job. A normal project rule produces one job;
      a [Project_units] rule produces one job per enumerated unit. *)

  val file : t -> Context.file -> result list
  (** [file rule context] runs file rule. *)

  val project : t -> Context.project -> result list
  (** [project rule context] runs project rule. *)

  val project_jobs : t -> Context.project -> project_job list
  (** [project_jobs rule context] exposes project work units for engine
      scheduling. *)

  val project_job : project_job -> result list
  (** [project_job job] runs one project job. *)

  val project_job_code : project_job -> string
  (** [project_job_code job] is the owning rule code. *)

  val code : result -> string
  (** [code result] returns rule code. *)

  val title : result -> string
  (** [title result] returns rule title. *)

  val pp : result Fmt.t
  (** [pp fmt result] pretty prints result. *)

  val location : result -> Location.t option
  (** [location result] returns location. *)

  val compare : result -> result -> int
  (** [compare r1 r2] compares results. *)
end
