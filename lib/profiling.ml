(** Simple profiling module for measuring execution times *)

type timing = { name : string; duration : float }

(** Profiling state that encapsulates mutable timings *)
type t = { mutable timings : timing list }

(** Create an empty profiling state *)
let create () = { timings = [] }

(** Add a timing to the profiling state *)
let add_timing t timing = t.timings <- timing :: t.timings

(** Get all timings in chronological order *)
let get_timings_from_state t = List.rev t.timings

(** Reset timings in the state *)
let reset_state t = t.timings <- []

let print_summary_from_state t =
  let timings = get_timings_from_state t in
  if timings <> [] then (
    Fmt.pr "\n[Profiling Summary]\n";
    Fmt.pr "%-40s %10s\n" "Operation" "Time (ms)";
    Fmt.pr "%s\n" (String.make 52 '-');

    (* Group timings by name and sum durations *)
    let grouped =
      List.fold_left
        (fun acc { name; duration } ->
          let current = try List.assoc name acc with Not_found -> 0.0 in
          (name, current +. duration) :: List.remove_assoc name acc)
        [] timings
    in

    (* Sort by duration descending *)
    let sorted = List.sort (fun (_, a) (_, b) -> compare b a) grouped in

    List.iter
      (fun (name, duration) ->
        Fmt.pr "%-40s %10.2f\n" name (duration *. 1000.0))
      sorted;

    (* Total time *)
    let total = List.fold_left (fun acc (_, d) -> acc +. d) 0.0 sorted in
    Fmt.pr "%s\n" (String.make 52 '-');
    Fmt.pr "%-40s %10.2f\n" "Total" (total *. 1000.0))

let print_per_file_summary_from_state t =
  let timings = get_timings_from_state t in
  if timings <> [] then
    (* Extract file-specific timings *)
    let file_timings =
      List.filter_map
        (fun { name; duration } ->
          (* Look for patterns like "Merlin: filename.ml" or "AST checks: filename.ml" *)
          try
            let colon_idx = String.index name ':' in
            if colon_idx > 0 && colon_idx < String.length name - 2 then
              let operation = String.sub name 0 colon_idx in
              let filename =
                String.trim
                  (String.sub name (colon_idx + 1)
                     (String.length name - colon_idx - 1))
              in
              Some (filename, operation, duration)
            else None
          with Not_found -> None)
        timings
    in

    if file_timings <> [] then (
      Fmt.pr "\n[Per-File Profiling]\n";
      Fmt.pr "%-50s %-20s %10s\n" "File" "Operation" "Time (ms)";
      Fmt.pr "%s\n" (String.make 82 '-');

      (* Group by file first *)
      let by_file = Hashtbl.create 32 in
      List.iter
        (fun (file, op, dur) ->
          let ops = try Hashtbl.find by_file file with Not_found -> [] in
          Hashtbl.replace by_file file ((op, dur) :: ops))
        file_timings;

      (* Convert to list and sort by total time per file *)
      let file_totals =
        Hashtbl.fold
          (fun file ops acc ->
            let total =
              List.fold_left (fun sum (_, dur) -> sum +. dur) 0.0 ops
            in
            (file, ops, total) :: acc)
          by_file []
      in
      let sorted_files =
        List.sort (fun (_, _, a) (_, _, b) -> compare b a) file_totals
      in

      (* Print each file *)
      List.iter
        (fun (file, ops, total) ->
          let sorted_ops = List.sort (fun (_, a) (_, b) -> compare b a) ops in
          List.iter
            (fun (op, dur) ->
              Fmt.pr "%-50s %-20s %10.2f\n" file op (dur *. 1000.0))
            sorted_ops;
          Fmt.pr "%-50s %-20s %10.2f\n" "" "[File Total]" (total *. 1000.0);
          Fmt.pr "\n")
        sorted_files)
