type Runtime_events.User.tag += Merlint

let events : (string, Runtime_events.Type.span Runtime_events.User.t) Hashtbl.t
    =
  Hashtbl.create 64

let lock = Eio.Mutex.create ()

let event name =
  Eio.Mutex.use_rw ~protect:true lock @@ fun () ->
  match Hashtbl.find_opt events name with
  | Some ev -> ev
  | None ->
      let ev =
        Runtime_events.User.register name Merlint Runtime_events.Type.span
      in
      Hashtbl.add events name ev;
      ev

let span name f =
  let ev = event name in
  Runtime_events.User.write ev Runtime_events.Type.Begin;
  Fun.protect
    ~finally:(fun () -> Runtime_events.User.write ev Runtime_events.Type.End)
    f

let rule_span code f = span ("merlint.rule." ^ code) f
let merlin_span what f = span ("merlint.merlin." ^ what) f
