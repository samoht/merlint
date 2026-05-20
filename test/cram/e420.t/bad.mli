(** [t] is the public state. *)
type t = { value : int }

(** [mode] selects the execution mode. *)
type mode = Fast | Slow

(** [E] is raised on failure. *)
exception E

(** [S] is a module type. *)
module type S = sig
  val run : unit -> unit
end

(** [M] implements [S]. *)
module M : S

(** [c] is a class. *)
class c : object
  method m : int
end

(** [ct] is a class type. *)
class type ct = object
  method n : int
end

(** [make x] builds a [t] with field [value], using constructor [Fast],
    module [M], module type [S], exception [E], class [c], and class type [ct].
*)
val make : int -> t
