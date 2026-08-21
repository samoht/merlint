let run () = assert (Mylib.greet "x" = Helper.prefix ^ "x")
let () = run ()
