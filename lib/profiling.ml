(** Simple profiling module for measuring execution times *)

type timing = { name : string; duration : float }

let timings = ref []

let time name f =
  let start = Unix.gettimeofday () in
  try
    let result = f () in
    let duration = Unix.gettimeofday () -. start in
    timings := { name; duration } :: !timings;
    result
  with e ->
    let duration = Unix.gettimeofday () -. start in
    timings := { name; duration } :: !timings;
    raise e

let reset () = timings := []
let get_timings () = List.rev !timings

let print_summary () =
  let timings = get_timings () in
  if timings <> [] then (
    Printf.printf "\n[Profiling Summary]\n";
    Printf.printf "%-40s %10s\n" "Operation" "Time (ms)";
    Printf.printf "%s\n" (String.make 52 '-');

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
        Printf.printf "%-40s %10.2f\n" name (duration *. 1000.0))
      sorted;

    (* Total time *)
    let total = List.fold_left (fun acc (_, d) -> acc +. d) 0.0 sorted in
    Printf.printf "%s\n" (String.make 52 '-');
    Printf.printf "%-40s %10.2f\n" "Total" (total *. 1000.0))
