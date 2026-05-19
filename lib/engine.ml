(** Linting engine *)

let src = Logs.Src.create "merlint.engine" ~doc:"Linting engine"

module Log = (val Logs.src_log src : Logs.LOG)

type exclusion_stats = { rule : string; file : string }
type result = { issues : Rule.Run.result list; excluded : exclusion_stats list }

type io_stats = {
  mutable files_read : int;
  mutable merlin_calls : int;
  reads_by_ext : (string, int) Hashtbl.t;
  merlin_by_ext : (string, int) Hashtbl.t;
  lock : Eio.Mutex.t;
}

let io_stats () =
  {
    files_read = 0;
    merlin_calls = 0;
    reads_by_ext = Hashtbl.create 8;
    merlin_by_ext = Hashtbl.create 8;
    lock = Eio.Mutex.create ();
  }

let with_stats_lock stats f =
  Eio.Mutex.lock stats.lock;
  Fun.protect ~finally:(fun () -> Eio.Mutex.unlock stats.lock) f

let ext filename =
  match Filename.extension filename with "" -> "<none>" | ext -> ext

let incr_ext tbl filename =
  let ext = ext filename in
  Hashtbl.replace tbl ext
    (Option.value ~default:0 (Hashtbl.find_opt tbl ext) + 1)

let record_file_read stats filename =
  with_stats_lock stats @@ fun () ->
  stats.files_read <- stats.files_read + 1;
  incr_ext stats.reads_by_ext filename

let record_merlin_call stats filename =
  with_stats_lock stats @@ fun () ->
  stats.merlin_calls <- stats.merlin_calls + 1;
  incr_ext stats.merlin_by_ext filename

let sorted_ext_counts tbl =
  Hashtbl.fold (fun ext count acc -> (ext, count) :: acc) tbl []
  |> List.sort (fun (a, _) (b, _) -> String.compare a b)

let warn_missing_cmts n =
  if n > 0 then
    Log.warn (fun m ->
        m
          "%d typedtree-backed quer%s found no fresh .cmt/.cmti file. The \
           affected typedtree-backed rule runs were skipped for those files; \
           run [dune build @check] (or pass [--build]) before merlint so the \
           build artefacts are present and up to date."
          n
          (if n = 1 then "y" else "ies"))

let log_fs_stats () =
  let s = Fs.stats () in
  if
    s.readdirs + s.is_directory_checks + s.file_exists_checks + s.file_opens > 0
  then
    Log.info (fun m ->
        m "FS stats: readdirs=%d is_directory=%d file_exists=%d file_opens=%d"
          s.readdirs s.is_directory_checks s.file_exists_checks s.file_opens)

let log_io_stats stats backend =
  let backend_stats = Merlin.stats backend in
  let reads = sorted_ext_counts stats.reads_by_ext in
  let merlin = sorted_ext_counts stats.merlin_by_ext in
  let all_exts =
    List.map fst reads @ List.map fst merlin |> List.sort_uniq String.compare
  in
  let lookup tbl ext = Option.value ~default:0 (Hashtbl.find_opt tbl ext) in
  Log.info (fun m ->
      m
        "IO stats: files_read=%d merlin_calls=%d cmt_hits=%d cmt_misses=%d \
         source_parses=%d cmt_reads=%d cmt_cache_hits=%d"
        stats.files_read stats.merlin_calls backend_stats.cmt_hits
        backend_stats.cmt_misses backend_stats.source_parses
        backend_stats.cmt_reads backend_stats.cmt_cache_hits);
  List.iter
    (fun ext ->
      Log.info (fun m ->
          m "IO stats[%s]: files_read=%d merlin_calls=%d" ext
            (lookup stats.reads_by_ext ext)
            (lookup stats.merlin_by_ext ext)))
    all_exts;
  warn_missing_cmts backend_stats.cmt_misses

let run_file_rule ?profiling ctx rule =
  let code = Rule.code rule in
  Log.debug (fun m -> m "Running rule %s on %s" code ctx.Context.filename);
  let start_time = Unix.gettimeofday () in
  let res =
    Trace.rule_span code @@ fun () ->
    try Rule.Run.file rule ctx
    with exn ->
      Log.err (fun m ->
          m "Rule %s failed on %s: %s" code ctx.Context.filename
            (Printexc.to_string exn));
      []
  in
  let duration = Unix.gettimeofday () -. start_time in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        {
          operation =
            Profiling.File_rule
              { rule_code = code; filename = ctx.Context.filename };
          duration;
        }
  | None -> ());
  res

let run_project_job ?profiling job =
  let code = Rule.Run.project_job_code job in
  Log.debug (fun m -> m "Running project rule job %s" code);
  let start_time = Unix.gettimeofday () in
  let res =
    Trace.rule_span code @@ fun () ->
    try Rule.Run.project_job job
    with exn ->
      Log.err (fun m ->
          m "Project rule job %s failed: %s" code (Printexc.to_string exn));
      []
  in
  let duration = Unix.gettimeofday () -. start_time in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        { operation = Profiling.Project_rule code; duration }
  | None -> ());
  res

let merlin_op ?profiling ?stats filename f =
  Option.iter (fun stats -> record_merlin_call stats filename) stats;
  let start = Unix.gettimeofday () in
  let r = Trace.merlin_span "typedtree" f in
  let duration = Unix.gettimeofday () -. start in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        { operation = Profiling.Merlin filename; duration }
  | None -> ());
  r

let source_filename filename =
  let file = Fpath.v filename in
  if Fpath.is_abs file then Fpath.to_string (Fpath.normalize file)
  else Fpath.(v (Sys.getcwd ()) // file |> normalize |> to_string)

let file_view ?profiling ~stats ~load_file ~backend filename =
  let source_filename = source_filename filename in
  let content =
    lazy
      (record_file_read stats filename;
       load_file source_filename)
  in
  let source = Merlin.Source.v ~file:source_filename ~content in
  let typedtree () =
    merlin_op ?profiling ?stats:(Some stats) filename (fun () ->
        Merlin.typedtree backend ~source)
  in
  File_view.v ~filename ~typedtree ()

let setup_analysis ~filter ~dune_describe ~analyze_set ~index ~file_view
    project_root =
  let config = Config.load project_root in
  let analyze_set = List.map Fpath.to_string analyze_set in
  let project_ctx =
    Context.project ~config ~project_root ~analyze_set ~dune_describe ~index
      ~file_view ()
  in
  let enabled_rules =
    Data.all_rules
    |> List.filter (fun rule ->
        Filter.is_enabled_by_code filter (Rule.code rule))
  in
  (config, project_ctx, enabled_rules)

let config_lookup () =
  let cache = Hashtbl.create 32 in
  fun file ->
    let dir = if Sys.file_exists file then Filename.dirname file else file in
    match Hashtbl.find_opt cache dir with
    | Some c -> c
    | None ->
        let c = Config.for_file file in
        Hashtbl.add cache dir c;
        c

(* Per-rule excluded-accumulator pattern: each rule produces its own
   excluded list, and the caller flattens at the end. Avoids a shared ref
   when project rules run in parallel domains. *)
let split_excluded ~config_for ~code issues =
  let excluded = ref [] in
  let kept =
    List.filter
      (fun r ->
        match Rule.Run.location r with
        | None -> true
        | Some loc ->
            let file = loc.Location.file in
            let cfg : Config.t = config_for file in
            let skip =
              Rule_config.should_exclude cfg.exclusions ~rule:code ~file
            in
            if skip then excluded := { rule = code; file } :: !excluded;
            not skip)
      issues
  in
  (kept, List.rev !excluded)

let run_one_project_job ?profiling ~config_for job =
  let code = Rule.Run.project_job_code job in
  let issues = run_project_job ?profiling job in
  split_excluded ~config_for ~code issues

let run_project_rules ?domain_mgr ?profiling enabled_rules project_ctx =
  let config_for = config_lookup () in
  let rules = List.filter Rule.is_project_scoped enabled_rules in
  let jobs =
    List.concat_map (fun rule -> Rule.Run.project_jobs rule project_ctx) rules
  in
  let run = run_one_project_job ?profiling ~config_for in
  let results =
    match domain_mgr with
    | None -> List.map run jobs
    | Some dm -> Fs.parallel_map dm jobs run
  in
  let issues = List.concat_map fst results in
  let excluded = List.concat_map snd results in
  (issues, excluded)

let analyze_single_file ?profiling ~project_ctx ~config_for ~project_root
    ~file_rules filepath =
  let filename = Fpath.to_string filepath in
  let config = config_for filename in
  let excluded_acc = ref [] in
  let issues =
    try
      ignore profiling;
      let view = Context.file_view project_ctx filename in
      let file_ctx =
        Context.file_with_view ~filename ~config ~project_root ~view
          ~load_content:(fun () -> Context.file_content project_ctx filename)
      in
      let all_results =
        List.concat_map (run_file_rule ?profiling file_ctx) file_rules
      in
      List.filter
        (fun r ->
          let code = Rule.Run.code r in
          let skip =
            Rule_config.should_exclude config.exclusions ~rule:code
              ~file:filename
          in
          if skip then
            excluded_acc := { rule = code; file = filename } :: !excluded_acc;
          not skip)
        all_results
    with exn ->
      Log.err (fun m ->
          m "Failed to analyze %s: %s" filename (Printexc.to_string exn));
      []
  in
  (issues, List.rev !excluded_acc)

(** Group [files] by the opam package they live under (as known to
    {!Project_index}). Files not under any indexed package land in a single
    [None] bucket. *)
let group_files_by_package index files =
  let dir_to_pkg = Hashtbl.create 256 in
  Project_index.source_packages_nodes index
  |> List.iter (fun pkg ->
      match Project_index.Package.source_dir pkg with
      | None -> ()
      | Some dir ->
          Hashtbl.replace dir_to_pkg (Fpath.to_string dir)
            (Project_index.Package.name pkg));
  let pkg_of file =
    let rec walk dir =
      match Hashtbl.find_opt dir_to_pkg dir with
      | Some _ as pkg -> pkg
      | None ->
          let parent = Filename.dirname dir in
          if parent = dir then None else walk parent
    in
    walk (Filename.dirname (Fpath.to_string file))
  in
  let tbl = Hashtbl.create 16 in
  List.iter
    (fun file ->
      let key = pkg_of file in
      let prev = try Hashtbl.find tbl key with Not_found -> [] in
      Hashtbl.replace tbl key (file :: prev))
    files;
  Hashtbl.fold (fun k v acc -> (k, List.rev v) :: acc) tbl []

(** Walk [files] grouped by package, processing different packages in parallel
    via [domain_mgr] when supplied. Files within a single package are processed
    sequentially -- typedtree-walking rules share a Merlin backend whose
    compiler-libs state is process-global, so keeping one package per domain at
    a time avoids state mixing. *)
let analyze_files ?domain_mgr ~project_ctx ~project_root ~file_rules ?profiling
    files =
  let config_for = config_lookup () in
  let analyse filepath =
    analyze_single_file ?profiling ~project_ctx ~config_for ~project_root
      ~file_rules filepath
  in
  let analyse_pkg (_pkg, pkg_files) = List.map analyse pkg_files in
  match domain_mgr with
  | None -> List.map analyse files
  | Some dm ->
      let groups = group_files_by_package (Context.index project_ctx) files in
      Fs.parallel_map dm groups analyse_pkg |> List.concat

(* Vendored paths come from the root dune metadata. The library-owner check
   keeps the package-level query useful for files resolved through the index. *)
let file_is_vendored index file =
  Project_index.is_vendored_path index file
  ||
  match Project_index.libraries_of_file index file with
  | [] -> false
  | libs -> List.for_all Project_index.Library.is_vendored libs

let drop_vendored_files index files =
  List.filter (fun f -> not (file_is_vendored index f)) files

let run ?domain_mgr ~load_file ~filter ~dune_describe ?analyze_set ~index
    ?profiling project_root =
  Log.info (fun m -> m "Starting analysis of %s" project_root);
  let backend = Merlin.v ~root_dir:project_root () in
  let stats = io_stats () in
  let analyze_set =
    match analyze_set with
    | Some files -> files
    | None -> Dune_describe.project_files dune_describe
  in
  let analyze_set =
    let idx = Lazy.force index in
    drop_vendored_files idx analyze_set
  in
  let file_view = file_view ?profiling ~stats ~load_file ~backend in
  let _config, project_ctx, enabled_rules =
    setup_analysis ~filter ~dune_describe ~analyze_set ~index ~file_view
      project_root
  in
  Fs.reset_stats ();
  Fun.protect
    ~finally:(fun () ->
      log_io_stats stats backend;
      log_fs_stats ();
      Merlin.close backend)
    (fun () ->
      let project_issues, project_excluded =
        Trace.span "merlint.phase.project_rules" @@ fun () ->
        run_project_rules ?domain_mgr ?profiling enabled_rules project_ctx
      in
      let file_rules = List.filter Rule.is_file_scoped enabled_rules in
      let file_results =
        Trace.span "merlint.phase.file_rules" @@ fun () ->
        analyze_files ?domain_mgr ~project_ctx ~project_root ~file_rules
          ?profiling analyze_set
      in
      let file_issues = List.concat_map fst file_results in
      let file_excluded = List.concat_map snd file_results in
      {
        issues = List.sort Rule.Run.compare (project_issues @ file_issues);
        excluded = project_excluded @ file_excluded;
      })
