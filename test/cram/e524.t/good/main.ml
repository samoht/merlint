open Cmdliner

let foo = Cmd.v (Cmd.info "foo") Term.(const ())

let () = exit (Cmd.eval foo)
