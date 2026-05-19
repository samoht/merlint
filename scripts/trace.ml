(* Aggregate merlint Trace spans from a Runtime_events ring.

   Usage:
     OCAMLRUNPARAM='e=20' \
     OCAML_RUNTIME_EVENTS_START=1 \
     OCAML_RUNTIME_EVENTS_DIR=/tmp/merlint-trace \
     OCAML_RUNTIME_EVENTS_PRESERVE=1 \
       merlint --no-build .

     dune exec ./scripts/trace.exe -- /tmp/merlint-trace <pid>

   Reads every span whose name starts with [merlint.] and prints the
   per-name total wall time, count, and average. The default ring (2^15
   events per domain) wraps long before merlint finishes on a real
   monorepo; [e=20] is a 32 MB ring that keeps every span. *)

let () =
  if Array.length Sys.argv < 3 then (
    Fmt.epr "usage: trace <events-dir> <pid>@.";
    exit 2)

let dir = Sys.argv.(1)
let pid = int_of_string Sys.argv.(2)
let totals : (string, float * int) Hashtbl.t = Hashtbl.create 256
let active : (int * string, int64) Hashtbl.t = Hashtbl.create 256
let dropped_ends = ref 0

let add name dur =
  let prev_t, prev_n =
    Option.value ~default:(0.0, 0) (Hashtbl.find_opt totals name)
  in
  Hashtbl.replace totals name (prev_t +. dur, prev_n + 1)

let user_callback domain ts ev kind =
  let name = Runtime_events.User.name ev in
  if String.starts_with ~prefix:"merlint." name then
    let ts_ns = Runtime_events.Timestamp.to_int64 ts in
    match kind with
    | Runtime_events.Type.Begin -> Hashtbl.replace active (domain, name) ts_ns
    | Runtime_events.Type.End -> (
        match Hashtbl.find_opt active (domain, name) with
        | None -> incr dropped_ends
        | Some start ->
            Hashtbl.remove active (domain, name);
            let dur_ns = Int64.sub ts_ns start in
            add name (Int64.to_float dur_ns /. 1e9))

let () =
  let cursor = Runtime_events.create_cursor (Some (dir, pid)) in
  let cb =
    Runtime_events.Callbacks.create ()
    |> Runtime_events.Callbacks.add_user_event Runtime_events.Type.span
         user_callback
  in
  let rec drain () =
    let n = Runtime_events.read_poll cursor cb None in
    if n > 0 then drain ()
  in
  drain ();
  let entries =
    Hashtbl.fold
      (fun name (total, count) acc -> (name, total, count) :: acc)
      totals []
    |> List.sort (fun (_, a, _) (_, b, _) -> compare b a)
  in
  Fmt.pr "%-50s %10s %8s %12s@." "span" "total(s)" "count" "avg(ms)";
  List.iter
    (fun (name, total, count) ->
      Fmt.pr "%-50s %10.3f %8d %12.3f@." name total count
        (total *. 1000. /. float_of_int count))
    entries;
  if !dropped_ends > 0 then
    Fmt.epr "warning: %d End events with no matching Begin (ring overflow?)@."
      !dropped_ends
