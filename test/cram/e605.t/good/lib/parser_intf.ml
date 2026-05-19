(* Companion interface for parser.ml -- carries only module types. *)

module type S = sig
  type token = Int of int | Plus | Minus | EOF

  val tokenize : string -> token list
  val parse : token list -> int
end
