(** Typedtree query helpers shared by rules. *)

module Path : sig
  val parts : Ocaml_typing.Path.t -> string list
  (** [parts path] returns the cleaned components of [path]. *)

  val ends_with : Ocaml_typing.Path.t -> string list -> bool
  (** [ends_with path suffix] checks whether [path] ends with [suffix]. *)
end

module Longident : sig
  val parts : Ocaml_parsing.Longident.t -> string list
  (** [parts lid] returns the components of [lid]. *)

  val ends_with : Ocaml_parsing.Longident.t -> string list -> bool
  (** [ends_with lid suffix] checks whether [lid] ends with [suffix]. *)
end

module Expr : sig
  val callee_parts : Ocaml_typing.Typedtree.expression -> string list option
  (** [callee_parts expr] returns the resolved callee components when [expr] is
      a call-like expression. *)

  val callee_ends_with : Ocaml_typing.Typedtree.expression -> string list -> bool
  (** [callee_ends_with expr suffix] checks the resolved callee suffix. *)

  val calls : Ocaml_typing.Typedtree.expression -> string list -> bool
  (** [calls expr suffix] checks whether [expr] calls a callee ending in
      [suffix]. *)

  val positional_args :
    (Ocaml_parsing.Asttypes.arg_label * Ocaml_typing.Typedtree.apply_arg) list ->
    Ocaml_typing.Typedtree.expression list
  (** [positional_args args] returns the supplied unlabelled call arguments. *)

  val last_positional_arg :
    (Ocaml_parsing.Asttypes.arg_label * Ocaml_typing.Typedtree.apply_arg) list ->
    Ocaml_typing.Typedtree.expression option
  (** [last_positional_arg args] returns the last supplied unlabelled call
      argument. *)

  val string : Ocaml_typing.Typedtree.expression -> string option
  (** [string expr] returns the string constant carried by [expr], if any. *)

  val body :
    Ocaml_typing.Typedtree.expression -> Ocaml_typing.Typedtree.expression
  (** [body expr] unwraps function expressions to their body expression. *)
end

module Pattern : sig
  val var_name : 'k Ocaml_typing.Typedtree.general_pattern -> string option
  (** [var_name pat] returns the variable name bound by [pat], if any. *)
end

val iter_expressions :
  File_view.t -> (Ocaml_typing.Typedtree.expression -> unit) -> unit
(** [iter_expressions view f] applies [f] to implementation expressions. *)

val iter_value_bindings :
  File_view.t -> (Ocaml_typing.Typedtree.value_binding -> unit) -> unit
(** [iter_value_bindings view f] applies [f] to implementation value
    bindings. *)

val iter_structure_items :
  File_view.t -> (Ocaml_typing.Typedtree.structure_item -> unit) -> unit
(** [iter_structure_items view f] applies [f] to implementation items. *)

val iter_signature_items :
  File_view.t -> (Ocaml_typing.Typedtree.signature_item -> unit) -> unit
(** [iter_signature_items view f] applies [f] to interface items. *)
