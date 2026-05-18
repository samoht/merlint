type t = int

val print : t Fmt.t

type widget = { x : int }

val dump_widget : Format.formatter -> widget -> unit
