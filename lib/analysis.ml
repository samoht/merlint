type file_facts = { suite_callers : Suite.callers option }
type t = { facts : (string, file_facts) Hashtbl.t; lock : Eio.Mutex.t }

let walk view = { suite_callers = Suite.callers view }

let build ?pool ~view_of files =
  let t = { facts = Hashtbl.create 256; lock = Eio.Mutex.create () } in
  let process file =
    let view = view_of file in
    let facts = walk view in
    Eio.Mutex.use_rw ~protect:true t.lock (fun () ->
        Hashtbl.replace t.facts file facts)
  in
  (match pool with
  | None -> List.iter process files
  | Some pool -> Fs.parallel_map pool files process |> ignore);
  t

let suite_callers t filename =
  match Hashtbl.find_opt t.facts filename with
  | None -> None
  | Some facts -> facts.suite_callers
