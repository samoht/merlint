(* Both dependencies are genuinely imported: [Wire] from the wire codec and
   [Spy] from the spy library. *)
let run () = Wire.encode (String.length Spy.greet)
