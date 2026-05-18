(** Thin counted wrappers around [Sys] / [Stdlib] filesystem primitives so
    rules can be profiled by I/O class (directory scans, existence checks,
    open-for-read).

    The counters are process-level and reset by {!reset_stats}; the engine
    snapshots them via {!stats} after each run and logs them alongside the
    other I/O numbers. *)

type counters = {
  mutable readdirs : int;
  mutable is_directory_checks : int;
  mutable file_exists_checks : int;
  mutable file_opens : int;
}

type stats = {
  readdirs : int;
  is_directory_checks : int;
  file_exists_checks : int;
  file_opens : int;
}

let stats_record : counters =
  { readdirs = 0; is_directory_checks = 0; file_exists_checks = 0; file_opens = 0 }

let reset_stats () =
  stats_record.readdirs <- 0;
  stats_record.is_directory_checks <- 0;
  stats_record.file_exists_checks <- 0;
  stats_record.file_opens <- 0

let stats () : stats =
  {
    readdirs = stats_record.readdirs;
    is_directory_checks = stats_record.is_directory_checks;
    file_exists_checks = stats_record.file_exists_checks;
    file_opens = stats_record.file_opens;
  }

let readdir dir =
  stats_record.readdirs <- stats_record.readdirs + 1;
  Sys.readdir dir

let readdir_or_empty dir =
  try readdir dir |> Array.to_list with Sys_error _ -> []

let is_directory path =
  stats_record.is_directory_checks <- stats_record.is_directory_checks + 1;
  try Sys.is_directory path with Sys_error _ -> false

let file_exists path =
  stats_record.file_exists_checks <- stats_record.file_exists_checks + 1;
  Sys.file_exists path

let with_open_in_bin path f =
  stats_record.file_opens <- stats_record.file_opens + 1;
  let ic = open_in_bin path in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () -> f ic)

let with_open_in path f =
  stats_record.file_opens <- stats_record.file_opens + 1;
  let ic = open_in path in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () -> f ic)

let read_file path =
  with_open_in path (fun ic ->
      really_input_string ic (in_channel_length ic))
