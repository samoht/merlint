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

type 'a pass =
  | Pass : {
      select : Context.file -> bool;
      init : Context.file -> 'state;
      expr : ('state -> Ocaml_typing.Typedtree.expression -> unit) option;
      value_binding :
        ('state -> Ocaml_typing.Typedtree.value_binding -> unit) option;
      structure_item :
        ('state -> Ocaml_typing.Typedtree.structure_item -> unit) option;
      signature_item :
        ('state -> Ocaml_typing.Typedtree.signature_item -> unit) option;
      finish : Context.file -> 'state -> 'a Issue.t list;
    }
      -> 'a pass  (** A rule fragment for the engine's shared traversal. *)

type 'a scope =
  | File of (Context.file -> 'a Issue.t list)
  | Pass of 'a pass
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

val pass :
  ?select:(Context.file -> bool) ->
  ?expr:('state -> Ocaml_typing.Typedtree.expression -> unit) ->
  ?value_binding:('state -> Ocaml_typing.Typedtree.value_binding -> unit) ->
  ?structure_item:('state -> Ocaml_typing.Typedtree.structure_item -> unit) ->
  ?signature_item:('state -> Ocaml_typing.Typedtree.signature_item -> unit) ->
  init:(Context.file -> 'state) ->
  finish:(Context.file -> 'state -> 'a Issue.t list) ->
  unit ->
  'a scope
(** [pass ?select ?expr ?value_binding ?structure_item ?signature_item ~init
     ~finish ()] creates a shared traversal scope with no-op callbacks for
    omitted node kinds. *)

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

val is_direct_file_scoped : t -> bool
(** [is_direct_file_scoped rule] checks whether [rule] runs as a standalone file
    function. *)

val uses_pass : t -> bool
(** [uses_pass rule] checks whether [rule] participates in the shared pass. *)

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

  type active_pass
  (** One active pass for a concrete file. *)

  val file : t -> Context.file -> result list
  (** [file rule context] runs file rule. *)

  val pass : t -> Context.file -> active_pass option
  (** [pass rule context] initializes [rule]'s pass for [context], when any. *)

  val pass_expr :
    active_pass -> (Ocaml_typing.Typedtree.expression -> unit) option
  (** Expression callback registered by an active pass. *)

  val pass_value_binding :
    active_pass -> (Ocaml_typing.Typedtree.value_binding -> unit) option
  (** Value-binding callback registered by an active pass. *)

  val pass_structure_item :
    active_pass -> (Ocaml_typing.Typedtree.structure_item -> unit) option
  (** Structure-item callback registered by an active pass. *)

  val pass_signature_item :
    active_pass -> (Ocaml_typing.Typedtree.signature_item -> unit) option
  (** Signature-item callback registered by an active pass. *)

  val pass_finish : active_pass -> result list
  (** Finish an active pass and package its issues. *)

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
