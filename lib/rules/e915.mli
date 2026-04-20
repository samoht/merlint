(** E915: Opam tag metadata enforcement.

    Every [*.opam] file must declare [tags:] with an [org:*] marker and topics
    from the vocabulary configured in [.merlint]. *)

val rule : Rule.t
(** The E915 rule definition. *)
