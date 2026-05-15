(** Unified per-file view across the representations rules consume.

    A file can be observed at multiple levels of richness: typed AST ([.cmt]) at
    the top, parsetree ([Parse.implementation]) below, Merlin's dump and outline
    alongside (parsetree-level info enriched with build context), and raw bytes
    at the bottom. Today only parsetree, dump, outline, and raw bytes are used;
    reading [.cmt] is left as future work.

    [File_view.t] threads a single lazy through each level so the same file is
    parsed at most once per representation, and so a richer level can feed a
    less-rich derived view (e.g. [functions] reuses the shared parsetree).
    Accessors fall back to the next available level when the richer one is
    unavailable. *)

exception Analysis_error of string
(** Raised by the lazy accessors when the underlying source cannot be read (file
    I/O failure, Merlin error, ...). *)

type t

val v :
  filename:string ->
  outline:(unit -> (Outline.t, string) result) ->
  dump:(unit -> (Merlin.Dump.t, string) result) ->
  t
(** [v ~filename ~outline ~dump] builds a fresh view over [filename]. The
    [outline] / [dump] thunks are called on first access and never twice. *)

val filename : t -> string

val content : t -> string
(** Raw bytes of the file. *)

val parsetree : t -> Parsetree.structure option
(** Compiler-libs parsetree, shared between all derived views. Returns None for
    .mli files and parse errors. *)

val functions : t -> (string * Ast.expr) list
(** Top-level functions with their control flow, derived from the shared
    parsetree. *)

val ast : t -> Ast.t
(** Control-flow AST, derived from the shared parsetree. *)

val dump : t -> Merlin.Dump.t
(** Merlin's dump (identifiers, variants, patterns, value sigs). Forces the
    Merlin call on first access. *)

val outline : t -> Outline.t
(** Merlin's outline. Forces the Merlin call on first access. *)
