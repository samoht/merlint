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
let v () = { timings = [] }

(** Add a timing to the profiling state *)
let add_timing t timing = t.timings <- timing :: t.timings

(** Get all timings in chronological order *)
let timings_from_state t = List.rev t.timings

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

let ms f = Fmt.str "%.1f" (f *. 1000.0)

let print_summary t =
  let timings = timings_from_state t in
  if timings = [] then ()
  else
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
    let pct t =
      if total_time > 0.0 then Fmt.str "%.1f%%" (t /. total_time *. 100.0)
      else ""
    in
    let avg t c =
      if c > 0 then Fmt.str "%.1f" (t *. 1000.0 /. float_of_int c) else ""
    in
    let total_count = !merlin_count + !file_rule_count + !project_rule_count in

    let columns =
      Tty.Table.
        [
          column "Operation";
          column ~align:`Right "Count";
          column ~align:`Right "Total (ms)";
          column ~align:`Right "Avg (ms)";
          column ~align:`Right "% Time";
        ]
    in
    let rows = ref [] in
    let add name count time =
      if count > 0 then
        rows :=
          [ name; string_of_int count; ms time; avg time count; pct time ]
          :: !rows
    in
    add "Merlin Analysis" !merlin_count !merlin_time;
    add "File Rules" !file_rule_count !file_rules_time;
    add "Project Rules" !project_rule_count !project_rules_time;
    rows :=
      [ "Total"; string_of_int total_count; ms total_time; ""; "" ] :: !rows;

    Fmt.pr "@.[Profiling Summary]@.";
    let table =
      Tty.Table.of_string_rows ~border:Tty.Border.none columns (List.rev !rows)
    in
    Tty.Table.pp Format.std_formatter table

let print_file_summary t =
  let timings = timings_from_state t in
  if timings = [] then ()
  else
    let file_timings =
      List.filter_map
        (fun { operation; duration } ->
          match operation with
          | Merlin filename -> Some (filename, true, duration)
          | File_rule { filename; _ } -> Some (filename, false, duration)
          | _ -> None)
        timings
    in
    if file_timings = [] then ()
    else
      let by_file = Hashtbl.create 32 in
      List.iter
        (fun (file, is_merlin, dur) ->
          let m, r, c =
            try Hashtbl.find by_file file with Not_found -> (0.0, 0.0, 0)
          in
          if is_merlin then Hashtbl.replace by_file file (m +. dur, r, c)
          else Hashtbl.replace by_file file (m, r +. dur, c + 1))
        file_timings;

      let file_stats =
        Hashtbl.fold
          (fun file (merlin, rules, count) acc ->
            (file, merlin, rules, count) :: acc)
          by_file []
      in
      let sorted =
        List.sort
          (fun (_, m1, r1, _) (_, m2, r2, _) -> compare (m2 +. r2) (m1 +. r1))
          file_stats
      in
      let top = take 10 sorted in
      let remaining = List.length sorted - List.length top in

      let total_merlin =
        List.fold_left (fun acc (_, m, _, _) -> acc +. m) 0.0 sorted
      in
      let total_rules =
        List.fold_left (fun acc (_, _, r, _) -> acc +. r) 0.0 sorted
      in

      let columns =
        Tty.Table.
          [
            column "File";
            column ~align:`Right "Merlin (ms)";
            column ~align:`Right "Rules (ms)";
            column ~align:`Right "#Rules";
            column ~align:`Right "Total (ms)";
          ]
      in
      let rows =
        List.map
          (fun (file, merlin, rules, count) ->
            [
              file;
              ms merlin;
              ms rules;
              string_of_int count;
              ms (merlin +. rules);
            ])
          top
      in
      let rows =
        if remaining > 0 then
          rows @ [ [ Fmt.str "... (%d more)" remaining; ""; ""; ""; "" ] ]
        else rows
      in
      let rows =
        rows
        @ [
            [
              Fmt.str "Total (%d files)" (List.length sorted);
              ms total_merlin;
              ms total_rules;
              string_of_int (List.length sorted);
              ms (total_merlin +. total_rules);
            ];
          ]
      in

      Fmt.pr "@.[Top Slowest Files]@.";
      let table =
        Tty.Table.of_string_rows ~border:Tty.Border.none columns rows
      in
      Tty.Table.pp Format.std_formatter table

let print_rule_summary t =
  let timings = timings_from_state t in
  if timings = [] then ()
  else
    let rule_timings =
      List.filter_map
        (fun { operation; duration } ->
          match operation with
          | File_rule { rule_code; _ } -> Some (rule_code, duration, false)
          | Project_rule rule_code -> Some (rule_code, duration, true)
          | _ -> None)
        timings
    in
    if rule_timings = [] then ()
    else
      let by_rule = Hashtbl.create 32 in
      List.iter
        (fun (code, dur, is_project) ->
          let count, total, _ =
            try Hashtbl.find by_rule code
            with Not_found -> (0, 0.0, is_project)
          in
          Hashtbl.replace by_rule code (count + 1, total +. dur, is_project))
        rule_timings;

      let rule_stats =
        Hashtbl.fold
          (fun code (count, total, is_project) acc ->
            (code, count, total, is_project) :: acc)
          by_rule []
      in
      let sorted =
        List.sort (fun (_, _, a, _) (_, _, b, _) -> compare b a) rule_stats
      in

      (* Show rules > 1ms, or top 5 if none, capped at 10 *)
      let significant =
        List.filter (fun (_, _, total, _) -> total *. 1000.0 > 1.0) sorted
      in
      let to_show =
        if significant = [] then take 5 sorted
        else if List.length significant > 10 then take 10 significant
        else significant
      in

      if to_show = [] then ()
      else
        let remaining = List.length sorted - List.length to_show in
        let columns =
          Tty.Table.
            [
              column "Rule";
              column "Type";
              column ~align:`Right "Calls";
              column ~align:`Right "Total (ms)";
              column ~align:`Right "Avg (ms)";
            ]
        in
        let rows =
          List.map
            (fun (code, count, total, is_project) ->
              let avg =
                Fmt.str "%.1f" (total *. 1000.0 /. float_of_int count)
              in
              [
                code;
                (if is_project then "Project" else "File");
                string_of_int count;
                ms total;
                avg;
              ])
            to_show
        in
        let rows =
          if remaining > 0 then
            rows @ [ [ Fmt.str "... (%d more)" remaining; ""; ""; ""; "" ] ]
          else rows
        in

        Fmt.pr "@.[Top Slowest Rules]@.";
        let table =
          Tty.Table.of_string_rows ~border:Tty.Border.none columns rows
        in
        Tty.Table.pp Format.std_formatter table
