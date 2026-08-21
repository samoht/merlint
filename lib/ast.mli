(** The parsetree of one source file.

    A parsetree is what the source says: the declarations it makes, where they
    are, the attributes and doc comments written on them. Reading it needs the
    file on disk and nothing else -- no artefact, no [.cmi] for a dependency, no
    typechecker -- so what merlint derives from one answers for a file nobody
    has ever built. *)

(** The type for a source file's parsetree. *)
type t =
  | Implementation of Parsetree.structure  (** The parsetree of a [.ml]. *)
  | Interface of Parsetree.signature  (** The parsetree of a [.mli]. *)

val pp : t Fmt.t
(** [pp] prints the tree back as the source it parses to. *)

val v : filename:string -> content:string -> t
(** [v ~filename ~content] parses [content] as [filename]'s kind: an interface
    when [filename] ends in [.mli], an implementation otherwise. Positions carry
    [filename], so a location taken from the tree names the file.

    Source that does not parse yields an empty tree rather than an error: a file
    caught mid-edit declares nothing this run can say anything about, which is
    the same answer as a file that declares nothing.

    The parser is a compiler-libs entry point and runs under {!Merlin.Cl_lock}.
*)
