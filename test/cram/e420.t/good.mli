(** [t] is the public state. *)
type t = { value : int }

(** [mode] selects the execution mode. *)
type mode = Fast | Slow

(** [extensible] is extensible. *)
type extensible = ..

(** [Added] extends {!type-extensible}. *)
type extensible += Added

(** [E] is raised on failure. *)
exception E

(** [S] is a module type. *)
module type S = sig
  val run : unit -> unit
end

(** [M] implements {!module-type-S}. *)
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

(** [make x] builds a {!type-t} with field {!field-value}, using constructor
    {!constructor-Fast}, extension {!extension-Added}, module {!module-M}, module
    type {!module-type-S}, exception {!exception-E}, class {!class-c}, class
    method {!class-c.method-m}, instance variable {!class-c.instance-variable-iv},
    class type {!class-type-ct}, and class type method
    {!class-type-ct.method-n}. It keeps [x], [tar], and [gzip] as code
    literals. *)
val make : int -> t
