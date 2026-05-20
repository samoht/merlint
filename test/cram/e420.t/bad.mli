(** [t] is the public state. *)
type t = { value : int }

(** [mode] selects the execution mode. *)
type mode = Fast | Slow

(** [extensible] is extensible. *)
type extensible = ..

(** [Added] extends [extensible]. *)
type extensible += Added

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
  val mutable iv : int
  method m : int
end

(** [ct] is a class type. *)
class type ct = object
  method n : int
end

(** [make x] builds a [t] with field [value], using constructor [Fast],
    extension [Added], module [M], module type [S], exception [E], class [c],
    class method [c.m], instance variable [c.iv], class type [ct], and class type
    method [ct.n].
*)
val make : int -> t
