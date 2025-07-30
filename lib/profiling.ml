(** Simple profiling module for measuring execution times *)

type operation_type =
  | Merlin of string
  | File_rule of { rule_code : string; filename : string }
  | Project_rule of string
  | Other of string

type timing = { operation : operation_type; duration : float }

type t = { mutable timings : timing list }
(** Profiling state that encapsulates mutable timings *)

(** Create an empty profiling state *)
let create () = { timings = [] }

(** Add a timing to the profiling state *)
let add_timing t timing = t.timings <- timing :: t.timings

(** Get all timings in chronological order *)
let get_timings_from_state t = List.rev t.timings

(** Reset timings in the state *)
let reset_state t = t.timings <- []

(** Standard functions using polymorphic equality and comparison *)
let equal = ( = )

let compare = compare

let pp ppf t =
  Fmt.pf ppf "Profiling state with %d timing%s" (List.length t.timings)
    (if List.length t.timings = 1 then "" else "s")

let operation_name = function
  | Merlin filename -> Fmt.str "Merlin: %s" filename
  | File_rule { rule_code; filename } ->
      Fmt.str "Rule %s: %s" rule_code filename
  | Project_rule rule_code -> Fmt.str "Project rule %s" rule_code
  | Other name -> name

let print_summary t =
  let timings = get_timings_from_state t in
  if timings <> [] then (
    Fmt.pr "\n[Profiling Summary]\n";
    Fmt.pr "%-40s %10s\n" "Operation" "Time (ms)";
    Fmt.pr "%s\n" (String.make 52 '-');

    (* Group timings by operation name and sum durations *)
    let grouped =
      List.fold_left
        (fun acc { operation; duration } ->
          let name = operation_name operation in
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

let print_file_summary t =
  let timings = get_timings_from_state t in
  if timings <> [] then
    (* Extract file-specific timings *)
    let file_timings =
      List.filter_map
        (fun { operation; duration } ->
          match operation with
          | Merlin filename -> Some (filename, "Merlin", duration)
          | File_rule { rule_code; filename } ->
              Some (filename, Fmt.str "Rule %s" rule_code, duration)
          | _ -> None)
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

let print_rule_summary t =
  let timings = get_timings_from_state t in
  if timings <> [] then
    (* Extract rule-specific timings *)
    let rule_timings =
      List.filter_map
        (fun { operation; duration } ->
          match operation with
          | File_rule { rule_code; _ } -> Some (rule_code, duration, false)
          | Project_rule rule_code -> Some (rule_code, duration, true)
          | _ -> None)
        timings
    in

    if rule_timings <> [] then (
      Fmt.pr "\n[Per-Rule Profiling]\n";
      Fmt.pr "%-10s %-15s %10s %10s %10s\n" "Rule" "Type" "Calls" "Total (ms)"
        "Avg (ms)";
      Fmt.pr "%s\n" (String.make 65 '-');

      (* Group by rule code *)
      let by_rule = Hashtbl.create 32 in
      List.iter
        (fun (code, dur, is_project) ->
          let stats =
            try Hashtbl.find by_rule code
            with Not_found -> (0, 0.0, is_project)
          in
          let count, total, _ = stats in
          Hashtbl.replace by_rule code (count + 1, total +. dur, is_project))
        rule_timings;

      (* Convert to list and sort by total time *)
      let rule_stats =
        Hashtbl.fold
          (fun code (count, total, is_project) acc ->
            (code, count, total, is_project) :: acc)
          by_rule []
      in
      let sorted_rules =
        List.sort (fun (_, _, a, _) (_, _, b, _) -> compare b a) rule_stats
      in

      (* Print each rule *)
      List.iter
        (fun (code, count, total, is_project) ->
          let rule_type = if is_project then "Project" else "File" in
          let avg = total /. float_of_int count in
          Fmt.pr "%-10s %-15s %10d %10.2f %10.2f\n" code rule_type count
            (total *. 1000.0) (avg *. 1000.0))
        sorted_rules;

      (* Total *)
      let total_time =
        List.fold_left (fun acc (_, _, t, _) -> acc +. t) 0.0 sorted_rules
      in
      let total_calls =
        List.fold_left (fun acc (_, c, _, _) -> acc + c) 0 sorted_rules
      in
      Fmt.pr "%s\n" (String.make 65 '-');
      Fmt.pr "%-10s %-15s %10d %10.2f %10.2f\n" "Total" "" total_calls
        (total_time *. 1000.0)
        (total_time *. 1000.0 /. float_of_int total_calls))
