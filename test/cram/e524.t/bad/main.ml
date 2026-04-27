open Cmdliner

let foo = Cmd.v (Cmd.info "foo") Term.(const ())
let bar = Cmd.v (Cmd.info "bar") Term.(const ())

let () = exit (Cmd.eval (Cmd.group (Cmd.info "app") [ foo; bar ]))
