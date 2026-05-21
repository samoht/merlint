module Codec : sig
  type 'a t

  val v : string -> unit -> unit -> unit t
end

val codec : unit Codec.t

val struct_ : Wire_3d.struct_def
(** EverParse 3D struct projection provided by wire itself. *)
