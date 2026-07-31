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

(** Entries live one module down, so their field names are not in the root
    namespace and no unqualified link to them would resolve. *)
module Raw : sig
  (** [entry] is one entry of a serialised node. *)
  type entry = { k : string; v : int }
end

(** [opts] carries the request options: [metadata] travels with the request and
    [retries] bounds the attempts. *)
type opts = { metadata : string; retries : int }

(** [left] counts on the left. *)
type left = { count : int }

(** [right] counts on the right. *)
type right = { count : int }

val scan : opts -> key:string -> ?metadata:string -> unit -> int
(** [scan opts ~key ()] walks the entries reachable from [key] in [O(log n + k)]
    time, where [k] is the number of matches. [metadata] overrides the one in
    [opts], and the [count] of visited nodes is not reported. *)

val expiry : opts -> int option
(** [expiry opts] is the deadline carried by [opts], or [None] when the caller
    set none. *)

val decode : string -> (int, string) result
(** [decode s] is the integer encoded in [s]. Every failure is reported as
    [Error], never by raising. *)

(** [alg] selects a signature algorithm. *)
type alg = None | HS256

(** [status] is the outcome of a run. *)
type status = Ok | Error

type outcome = { target : string  (** Where the whole run landed. *) }
(** The type for where a run landed. *)

(** The type for what one step did. *)
type step =
  | Moved of { target : string }
      (** The step moved something to [target], which is this constructor's
          own field and not {!type-outcome}'s. *)
