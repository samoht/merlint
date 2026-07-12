(* Frames use the Wire format; a text-based scanner would credit that token
   to spy's internal wire.ml as well, hiding the dead spy dependency. Only
   the compiler's import record tells them apart: this unit imports [Wire],
   never [Spy] or [Spy__Wire]. *)
let run () = Wire.encode 1
