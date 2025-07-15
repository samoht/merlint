(** Legacy API design module - all checks have been moved to rules/*.ml *)

(** Legacy function for unit tests - returns empty list since all checks moved
    to rules/*.ml *)
let check ~filename:_ ~outline:_ (_typedtree : Typedtree.t) = []
