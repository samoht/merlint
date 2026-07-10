(* Exempted by allowed_words: the name mirrors a C API entry point. *)
let find_objects () = [ 1; 2 ]

(* Not exempted: still flagged. *)
let find_name () = 42
