(** Fuzzes the sub-library [e710-stanza.codec], whose entry module is
    [E710_stanza_codec]: inside the package, the codec is just "codec". *)

let run () = ignore (E710_stanza_codec.decode "")
