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

let rec take n = function
  | [] -> []
  | _ when n <= 0 -> []
  | h :: t -> h :: take (n - 1) t

let print_summary ?(width = 80) t =
  let timings = get_timings_from_state t in
  if timings <> [] then (
    (* Calculate totals by operation type *)
    let merlin_time = ref 0.0 in
    let file_rules_time = ref 0.0 in
    let project_rules_time = ref 0.0 in
    let other_time = ref 0.0 in
    let merlin_count = ref 0 in
    let file_rule_count = ref 0 in
    let project_rule_count = ref 0 in

    List.iter
      (fun { operation; duration } ->
        match operation with
        | Merlin _ ->
            merlin_time := !merlin_time +. duration;
            incr merlin_count
        | File_rule _ ->
            file_rules_time := !file_rules_time +. duration;
            incr file_rule_count
        | Project_rule _ ->
            project_rules_time := !project_rules_time +. duration;
            incr project_rule_count
        | Other _ -> other_time := !other_time +. duration)
      timings;

    let total_time =
      !merlin_time +. !file_rules_time +. !project_rules_time +. !other_time
    in

    Fmt.pr "\n[Profiling Summary]\n";
    let sep_width = min width 75 in
    if width >= 75 then
      Fmt.pr "%-25s %8s %10s %8s %8s\n" "Operation Type" "Count" "Total (ms)"
        "Avg (ms)" "% Time"
    else Fmt.pr "%-20s %6s %9s %7s\n" "Type" "Count" "Time (ms)" "%";
    Fmt.pr "%s\n" (String.make sep_width '-');

    if !merlin_count > 0 then
      if width >= 75 then
        Fmt.pr "%-25s %8d %10.2f %8.2f %7.1f%%\n" "Merlin Analysis"
          !merlin_count (!merlin_time *. 1000.0)
          (!merlin_time *. 1000.0 /. float_of_int !merlin_count)
          (!merlin_time /. total_time *. 100.0)
      else
        Fmt.pr "%-20s %6d %9.1f %6.1f%%\n" "Merlin" !merlin_count
          (!merlin_time *. 1000.0)
          (!merlin_time /. total_time *. 100.0);

    if !file_rule_count > 0 then
      if width >= 75 then
        Fmt.pr "%-25s %8d %10.2f %8.2f %7.1f%%\n" "File Rules" !file_rule_count
          (!file_rules_time *. 1000.0)
          (!file_rules_time *. 1000.0 /. float_of_int !file_rule_count)
          (!file_rules_time /. total_time *. 100.0)
      else
        Fmt.pr "%-20s %6d %9.1f %6.1f%%\n" "File Rules" !file_rule_count
          (!file_rules_time *. 1000.0)
          (!file_rules_time /. total_time *. 100.0);

    if !project_rule_count > 0 then
      if width >= 75 then
        Fmt.pr "%-25s %8d %10.2f %8.2f %7.1f%%\n" "Project Rules"
          !project_rule_count
          (!project_rules_time *. 1000.0)
          (!project_rules_time *. 1000.0 /. float_of_int !project_rule_count)
          (!project_rules_time /. total_time *. 100.0)
      else
        Fmt.pr "%-20s %6d %9.1f %6.1f%%\n" "Project Rules" !project_rule_count
          (!project_rules_time *. 1000.0)
          (!project_rules_time /. total_time *. 100.0);

    Fmt.pr "%s\n" (String.make sep_width '-');
    if width >= 75 then
      Fmt.pr "%-25s %8d %10.2f %8s %8s\n" "Total"
        (!merlin_count + !file_rule_count + !project_rule_count)
        (total_time *. 1000.0) "" ""
    else
      Fmt.pr "%-20s %6d %9.1f %7s\n" "Total"
        (!merlin_count + !file_rule_count + !project_rule_count)
        (total_time *. 1000.0) "")

let extract_file_timings timings =
  List.filter_map
    (fun { operation; duration } ->
      match operation with
      | Merlin filename -> Some (filename, "Merlin", duration)
      | File_rule { rule_code; filename } ->
          Some (filename, Fmt.str "Rule %s" rule_code, duration)
      | _ -> None)
    timings

let group_file_timings file_timings =
  let by_file = Hashtbl.create 32 in
  List.iter
    (fun (file, op, dur) ->
      let stats =
        try Hashtbl.find by_file file with Not_found -> (0.0, 0.0, 0)
      in
      let merlin_time, rules_time, rule_count = stats in
      if op = "Merlin" then
        Hashtbl.replace by_file file (merlin_time +. dur, rules_time, rule_count)
      else
        Hashtbl.replace by_file file
          (merlin_time, rules_time +. dur, rule_count + 1))
    file_timings;
  by_file

let print_file_summary ?(width = 80) t =
  let timings = get_timings_from_state t in
  if timings = [] then ()
  else
    let file_timings = extract_file_timings timings in
    if file_timings = [] then ()
    else
      let by_file = group_file_timings file_timings in

      (* Convert to list and sort by total time per file *)
      let file_stats =
        Hashtbl.fold
          (fun file (merlin, rules, count) acc ->
            (file, merlin, rules, count, merlin +. rules) :: acc)
          by_file []
      in
      let sorted_files =
        List.sort
          (fun (_, _, _, _, a) (_, _, _, _, b) -> compare b a)
          file_stats
      in

      (* Show only top 10 slowest files *)
      let top_files =
        match sorted_files with
        | [] -> []
        | files ->
            let top = take 10 files in
            if List.length files > 10 then top @ [ ("...", 0.0, 0.0, 0, 0.0) ]
            else top
      in

      Fmt.pr "\n[Top Slowest Files]\n";
      let sep_width = min width 80 in
      if width >= 80 then (
        Fmt.pr "%-30s %10s %10s %6s %10s\n" "File" "Merlin (ms)" "Rules (ms)"
          "#Rules" "Total (ms)";
        Fmt.pr "%s\n" (String.make sep_width '-'))
      else (
        Fmt.pr "%-25s %9s %9s %9s\n" "File" "Merlin" "Rules" "Total";
        Fmt.pr "%s\n" (String.make sep_width '-'));

      List.iter
        (fun (file, merlin, rules, count, total) ->
          if file = "..." then
            if width >= 80 then
              Fmt.pr "%-30s %10s %10s %6s %10s\n" "..." "" "" ""
                (Fmt.str "(%d more)" (List.length sorted_files - 10))
            else
              Fmt.pr "%-25s %9s %9s %9s\n" "..." "" ""
                (Fmt.str "(%d more)" (List.length sorted_files - 10))
          else
            let truncated_file =
              if width >= 80 then file
              else if String.length file > 25 then String.sub file 0 22 ^ "..."
              else file
            in
            if width >= 80 then
              Fmt.pr "%-30s %10.1f %10.1f %6d %10.1f\n" truncated_file
                (merlin *. 1000.0) (rules *. 1000.0) count (total *. 1000.0)
            else
              Fmt.pr "%-25s %9.0f %9.0f %9.0f\n" truncated_file
                (merlin *. 1000.0) (rules *. 1000.0) (total *. 1000.0))
        top_files;

      (* Summary stats *)
      let total_merlin =
        List.fold_left (fun acc (_, m, _, _, _) -> acc +. m) 0.0 sorted_files
      in
      let total_rules =
        List.fold_left (fun acc (_, _, r, _, _) -> acc +. r) 0.0 sorted_files
      in
      let total_files = List.length sorted_files in
      Fmt.pr "%s\n" (String.make sep_width '-');
      if width >= 80 then
        Fmt.pr "%-30s %10.1f %10.1f %6d %10.1f\n"
          (Fmt.str "Total (%d files)" total_files)
          (total_merlin *. 1000.0) (total_rules *. 1000.0) total_files
          ((total_merlin +. total_rules) *. 1000.0)
      else
        Fmt.pr "%-25s %9.0f %9.0f %9.0f\n"
          (Fmt.str "Total (%d)" total_files)
          (total_merlin *. 1000.0) (total_rules *. 1000.0)
          ((total_merlin +. total_rules) *. 1000.0)

let extract_rule_timings timings =
  List.filter_map
    (fun { operation; duration } ->
      match operation with
      | File_rule { rule_code; _ } -> Some (rule_code, duration, false)
      | Project_rule rule_code -> Some (rule_code, duration, true)
      | _ -> None)
    timings

let group_rule_timings rule_timings =
  let by_rule = Hashtbl.create 32 in
  List.iter
    (fun (code, dur, is_project) ->
      let stats =
        try Hashtbl.find by_rule code with Not_found -> (0, 0.0, is_project)
      in
      let count, total, _ = stats in
      Hashtbl.replace by_rule code (count + 1, total +. dur, is_project))
    rule_timings;
  by_rule

let print_rule_summary ?(width = 80) t =
  let timings = get_timings_from_state t in
  if timings = [] then ()
  else
    let rule_timings = extract_rule_timings timings in
    if rule_timings = [] then ()
    else
      let by_rule = group_rule_timings rule_timings in

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

      (* Filter to show only rules that took > 1ms or top 10 *)
      let significant_rules =
        sorted_rules
        |> List.filter (fun (_, _, total, _) -> total *. 1000.0 > 1.0)
      in

      let rules_to_show =
        if significant_rules = [] then
          (* If no rules > 1ms, show top 5 *)
          take 5 sorted_rules
        else if List.length significant_rules > 10 then
          (* Too many significant rules, limit to top 10 *)
          take 10 significant_rules
        else significant_rules
      in

      if rules_to_show <> [] then (
        Fmt.pr "\n[Top Slowest Rules]\n";
        let sep_width = min width 65 in
        if width >= 65 then (
          Fmt.pr "%-8s %-10s %8s %10s %8s\n" "Rule" "Type" "Calls" "Total (ms)"
            "Avg (ms)";
          Fmt.pr "%s\n" (String.make sep_width '-'))
        else (
          Fmt.pr "%-6s %-8s %8s %9s\n" "Rule" "Type" "Calls" "Time";
          Fmt.pr "%s\n" (String.make sep_width '-'));

        (* Print each rule *)
        List.iter
          (fun (code, count, total, is_project) ->
            let rule_type = if is_project then "Project" else "File" in
            let avg = total /. float_of_int count in
            if width >= 65 then
              Fmt.pr "%-8s %-10s %8d %10.1f %8.1f\n" code rule_type count
                (total *. 1000.0) (avg *. 1000.0)
            else
              Fmt.pr "%-6s %-8s %8d %9.0f\n" code rule_type count
                (total *. 1000.0))
          rules_to_show;

        (* Show if there are more *)
        let remaining = List.length sorted_rules - List.length rules_to_show in
        if remaining > 0 then
          if width >= 65 then
            Fmt.pr "%-8s %-10s %8s %10s %8s\n" "..." "" "" ""
              (Fmt.str "(%d more)" remaining)
          else
            Fmt.pr "%-6s %-8s %8s %9s\n" "..." "" ""
              (Fmt.str "(%d more)" remaining))
