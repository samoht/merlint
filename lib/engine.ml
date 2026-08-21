(** Linting engine *)

let src = Logs.Src.create "merlint.engine" ~doc:"Linting engine"

module Log = (val Logs.src_log src : Logs.LOG)
module T = Ocaml_typing.Typedtree
module Tast_iterator = Ocaml_typing.Tast_iterator

type exclusion_stats = { rule : string; file : string }

type result = {
  issues : Rule.Run.result list;
  excluded : exclusion_stats list;
  files_analyzed : int;
  unchecked_files : string list;
}

(* The compiler records a source's doc comments as [ocaml.doc] attributes in the
   artefact it writes; merlin's own lexer does not emit doc comments at all, so
   a typedtree recovered by typechecking has none of them. Every rule that reads
   a doc comment (E405, E410, E420, E425) reads it off the typedtree and applies
   to interfaces, so a recovered interface is examined by every other rule and
   by none of those -- less than the run was asked for, and it says so rather
   than letting four rules report a clean absence they cannot see. An
   implementation has no doc rules and is fully examined. *)
let partly_examined stats =
  List.filter File_kind.is_mli stats.Merlin.recovered_files

(* A bounded sample: naming every file of a whole-repo run buries the message
   the warning is carrying. *)
let pp_sample ppf files =
  let sample = List.filteri (fun i _ -> i < 10) files in
  List.iter (fun file -> Fmt.pf ppf "@,%s" file) sample;
  let extra = List.length files - List.length sample in
  if extra > 0 then Fmt.pf ppf "@,... and %d more" extra

(* A file whose artefact no longer describes it is typechecked instead, so the
   only files a run cannot look at are the ones nothing could say what to type
   against. Those split two ways:
   - Missing: the build system knows no stanza that compiles the file, for a
     stanza the host does build -- it has simply never been built, and one
     [dune build] fixes it.
   - Unavailable: the file belongs to a platform- or config-gated stanza the
     host does not build, so the build system has nothing to say about it and
     never will here -- not the user's to fix.
   Only Missing warrants the "run dune build" warning. *)
let warn_unresolved ~index stats =
  let norm s = Fpath.(v s |> normalize |> to_string) in
  let is_gated =
    let tbl = Hashtbl.create 64 in
    Project_index.gated_source_files index
    |> List.iter (fun p -> Hashtbl.replace tbl (norm (Fpath.to_string p)) ());
    fun f -> Hashtbl.mem tbl (norm f)
  in
  let _unavailable, missing =
    List.partition is_gated stats.Merlin.unresolved_files
  in
  (if missing <> [] then
     let n = List.length missing in
     Log.warn (fun m ->
         m
           "@[<v>%d file%s has no typedtree: no build artefact describes %s \
            and the build system names no stanza that compiles %s, so nothing \
            says what to type %s against and the rules that read a typedtree \
            were skipped. Run [dune build @check] (or pass [--build]) before \
            merlint.%a@]"
           n
           (if n = 1 then "" else "s")
           (if n = 1 then "it" else "them")
           (if n = 1 then "it" else "them")
           (if n = 1 then "it" else "them")
           pp_sample missing));
  missing

let log_fs_stats () =
  let s = Fs.stats () in
  if
    s.readdirs + s.is_directory_checks + s.file_exists_checks + s.file_opens > 0
  then
    Log.info (fun m ->
        m "FS stats: readdirs=%d is_directory=%d file_exists=%d file_opens=%d"
          s.readdirs s.is_directory_checks s.file_exists_checks s.file_opens)

let log_backend_stats ~index backend =
  let s = Merlin.stats backend in
  Log.info (fun m ->
      m
        "Merlin stats: cmt_hits=%d cmt_misses=%d cmt_reads=%d typechecks=%d \
         source_parses=%d"
        s.cmt_hits s.cmt_misses s.cmt_reads s.typechecks s.source_parses);
  (* Typechecking a file costs about ten times an artefact read, so a run that
     did many of them was working from a tree nobody had built. Worth saying,
     but not a warning: the files were examined. *)
  (match s.recovered_files with
  | [] -> ()
  | recovered ->
      Log.info (fun m ->
          m "Typechecked %d file%s whose build artefact did not describe %s"
            (List.length recovered)
            (if List.length recovered = 1 then "" else "s")
            (if List.length recovered = 1 then "it" else "them")));
  let partly = partly_examined s in
  (if partly <> [] then
     let n = List.length partly in
     Log.warn (fun m ->
         m
           "@[<v>%d interface%s typechecked rather than read from an artefact, \
            which loses the doc comments: E405, E410, E420 and E425 could not \
            run on %s. Run [dune build @check] (or pass [--build]) before \
            merlint.%a@]"
           n
           (if n = 1 then " was" else "s were")
           (if n = 1 then "it" else "them")
           pp_sample partly));
  warn_unresolved ~index s @ partly

(* The whole-repo index builders are meant to run a handful of times per
   analysis (roughly once per project rule). A count orders of magnitude higher
   means one is being recomputed inside a per-file or per-stanza loop. *)
let log_index_stats index =
  match Project_index.scan_stats index with
  | [] -> ()
  | stats ->
      Log.info (fun m ->
          m "Project-index scans: %a"
            Fmt.(list ~sep:(any ", ") (pair ~sep:(any "=") string int))
            stats)

let run_file_rule ?profiling ctx rule =
  let code = Rule.code rule in
  let filename = Context.filename ctx in
  Log.debug (fun m -> m "Running rule %s on %s" code filename);
  let start_time = Unix.gettimeofday () in
  let res =
    try
      Probe_events.file_rule ~rule:code ~file:filename (fun () ->
          Rule.Run.file rule ctx)
    with exn ->
      Log.err (fun m ->
          m "Rule %s failed on %s: %s" code filename (Printexc.to_string exn));
      []
  in
  let duration = Unix.gettimeofday () -. start_time in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        {
          operation = Profiling.File_rule { rule_code = code; filename };
          duration;
        }
  | None -> ());
  res

let run_project_job ?profiling job =
  let code = Rule.Run.project_job_code job in
  Log.debug (fun m -> m "Running project rule job %s" code);
  let start_time = Unix.gettimeofday () in
  let res =
    try
      Probe_events.project_rule ~rule:code (fun () -> Rule.Run.project_job job)
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

let merlin_op ?profiling filename f =
  let start = Unix.gettimeofday () in
  let r = f () in
  let duration = Unix.gettimeofday () -. start in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        { operation = Profiling.Merlin filename; duration }
  | None -> ());
  r

let file_view ?profiling ~load_file ~backend filename =
  let source_filename = Context.string_of_path filename in
  let content = lazy (load_file source_filename) in
  let source = Merlin.Source.v ~file:source_filename ~content in
  let typedtree () =
    (* Only OCaml units have a typedtree. A grammar/lexer source (.mly/.mll) or
       any other non-.ml/.mli file has no .cmt of its own -- the generated .ml
       does -- so don't probe for one (which would be a spurious cmt miss). *)
    if not (File_kind.is_ml_or_mli source_filename) then Ok None
    else
      merlin_op ?profiling source_filename (fun () ->
          Merlin.typedtree backend ~source)
  in
  File_view.v ~filename:source_filename ~typedtree ()

let setup_analysis ~filter ~analyze_set ~index ~file_view project_root =
  (* Resolve a relative root (e.g. ".") against the cwd: the analyze_set paths
     derive from it via [Context.path_under], and [Context.project] requires
     those to be absolute so the file-view cache keys canonicalize. *)
  let project_root_path =
    if Filename.is_relative project_root then
      Context.path (Filename.concat (Sys.getcwd ()) project_root)
    else Context.path project_root
  in
  let project_root = Context.string_of_path project_root_path in
  let config = Config.load project_root in
  let analyze_set =
    List.map
      (fun file ->
        Context.path_under ~root:project_root_path (Fpath.to_string file))
      analyze_set
  in
  let project_ctx =
    Context.project ~config ~project_root:project_root_path ~analyze_set ~index
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

(* Decide a finding's fate against the file's exclusions: [skip] drops it, and
   [count] (only when skipped) marks it a suppressed finding for the stats. A
   wholesale ["*"] (vendored-tree) exclusion is a "do not lint" directive, so it
   skips but does not count. *)
let exclusion_decision exclusions ~code ~file =
  let skip = Rule_config.should_exclude exclusions ~rule:code ~file in
  let count = skip && not (Rule_config.is_wildcard_excluded exclusions ~file) in
  (skip, count)

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
            let skip, count = exclusion_decision cfg.exclusions ~code ~file in
            if count then excluded := { rule = code; file } :: !excluded;
            not skip)
      issues
  in
  (kept, List.rev !excluded)

let run_one_project_job ?profiling ~config_for job =
  let code = Rule.Run.project_job_code job in
  let issues = run_project_job ?profiling job in
  split_excluded ~config_for ~code issues

let pass_iterator passes =
  let on_attribute = List.filter_map Rule.Run.pass_attribute passes in
  let on_expr = List.filter_map Rule.Run.pass_expr passes in
  let on_value_binding = List.filter_map Rule.Run.pass_value_binding passes in
  let dispatch_attribute attr = List.iter (fun f -> f attr) on_attribute in
  let dispatch_expr expr = List.iter (fun f -> f expr) on_expr in
  let dispatch_value_binding vb = List.iter (fun f -> f vb) on_value_binding in
  {
    Tast_iterator.default_iterator with
    attribute =
      (fun this attr ->
        dispatch_attribute attr;
        Tast_iterator.default_iterator.attribute this attr);
    expr =
      (fun this expr ->
        dispatch_expr expr;
        Tast_iterator.default_iterator.expr this expr);
    value_binding =
      (fun this value_binding ->
        dispatch_value_binding value_binding;
        Tast_iterator.default_iterator.value_binding this value_binding);
  }

let run_passes passes ctx =
  match passes with
  | [] -> []
  | _ -> (
      match File_view.typedtree (Context.view ctx) with
      | None -> []
      | Some tree ->
          let on_structure_item =
            List.filter_map Rule.Run.pass_structure_item passes
          in
          let on_signature_item =
            List.filter_map Rule.Run.pass_signature_item passes
          in
          let dispatch_structure_item item =
            List.iter (fun f -> f item) on_structure_item
          in
          let dispatch_signature_item item =
            List.iter (fun f -> f item) on_signature_item
          in
          let iterator = pass_iterator passes in
          (match tree with
          | `Implementation structure ->
              List.iter dispatch_structure_item structure.T.str_items;
              iterator.structure iterator structure
          | `Interface signature ->
              List.iter dispatch_signature_item signature.T.sig_items;
              iterator.signature iterator signature);
          List.concat_map Rule.Run.pass_finish passes)

let run_project_rules ?pool ?profiling enabled_rules project_ctx =
  let config_for = config_lookup () in
  let rules = List.filter Rule.is_project_scoped enabled_rules in
  let jobs =
    List.concat_map (fun rule -> Rule.Run.project_jobs rule project_ctx) rules
  in
  let run = run_one_project_job ?profiling ~config_for in
  Probe_events.project_rules ~rules:(List.length rules) ~jobs:(List.length jobs)
  @@ fun () ->
  let results =
    match pool with
    | None -> List.map run jobs
    | Some pool -> Fs.parallel_map pool jobs run
  in
  let issues = List.concat_map fst results in
  let excluded = List.concat_map snd results in
  (issues, excluded)

let analyze_single_file ?profiling ~project_ctx ~config_for ~project_root:_
    ~file_rules ~pass_rules filepath =
  let filename = Context.resolve project_ctx filepath in
  let filename_s = Context.string_of_path filename in
  let config = config_for filename_s in
  let excluded_acc = ref [] in
  let issues =
    Probe_events.file_analysis ~file:filename_s
      ~file_rules:(List.length file_rules) ~pass_rules:(List.length pass_rules)
    @@ fun () ->
    try
      ignore profiling;
      let view = Context.file_view project_ctx filename in
      let file_ctx =
        Context.file_with_view ~filename ~config
          ~project_root:(Context.project_root project_ctx)
          ~view
          ~analyze_set:(Context.analyze_set project_ctx)
          ~selected_file:project_ctx.Context.in_analyze_set
          ~project_index:(Some (Context.index project_ctx))
          ~load_content:(fun () -> Context.file_content project_ctx filename)
      in
      let active_passes =
        List.filter_map (fun rule -> Rule.Run.pass rule file_ctx) pass_rules
      in
      let shared_results = run_passes active_passes file_ctx in
      let direct_results =
        List.concat_map (run_file_rule ?profiling file_ctx) file_rules
      in
      let all_results = shared_results @ direct_results in
      List.filter
        (fun r ->
          let code = Rule.Run.code r in
          let skip, count =
            exclusion_decision config.exclusions ~code ~file:filename_s
          in
          if count then
            excluded_acc := { rule = code; file = filename_s } :: !excluded_acc;
          not skip)
        all_results
    with exn ->
      Log.err (fun m ->
          m "Failed to analyze %s: %s" filename_s (Printexc.to_string exn));
      []
  in
  (issues, List.rev !excluded_acc)

(** Walk [files] in parallel across [domain_mgr]'s executor pool. Each file is
    its own work unit; the pool decides how to spread them across domains. The
    earlier per-package grouping protected a process-global compiler-libs state
    that [typedtree_from_cmt] hasn't touched since the [with_cmt_state] wrap was
    removed -- cmt loading is now pure [Marshal.from_channel] and safe to call
    concurrently from any domain. *)
let analyze_files ?pool ~project_ctx ~project_root ~file_rules ~pass_rules
    ?profiling files =
  match (file_rules, pass_rules) with
  | [], [] -> []
  | _ -> (
      let config_for = config_lookup () in
      let analyse filepath =
        analyze_single_file ?profiling ~project_ctx ~config_for ~project_root
          ~file_rules ~pass_rules filepath
      in
      match pool with
      | None -> List.map analyse files
      | Some pool -> Fs.parallel_map pool files analyse)

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

let analysis_files ?analyze_set ?analyze_roots ?(include_vendored = false) index
    =
  let raw =
    match (analyze_set, analyze_roots) with
    | Some files, None -> files
    | None, roots -> Project_index.source_files ~include_vendored ?roots index
    | Some files, Some roots ->
        Project_index.source_files ~include_vendored ~roots index
        |> List.rev_append files
        |> List.sort_uniq Fpath.compare
  in
  if include_vendored then raw else drop_vendored_files index raw

(* CLI [--exclude PATTERN] drops files matching any glob from the analysis,
   using the same matcher as [merlint.toml] exclusions. Patterns are matched
   against both the file's path relative to [project_root] (so [vendor/**]
   works regardless of cwd) and the raw path. *)
let drop_excluded_files ~project_root ~exclude files =
  match exclude with
  | [] -> files
  | patterns ->
      let root = Fpath.v project_root in
      let excluded file =
        let raw = Fpath.to_string file in
        let rel =
          match Fpath.relativize ~root file with
          | Some r -> Fpath.to_string r
          | None -> raw
        in
        List.exists
          (fun p ->
            Rule_config.matches_pattern p rel
            || Rule_config.matches_pattern p raw)
          patterns
      in
      List.filter (fun f -> not (excluded f)) files

let run_enabled_rules ?pool ?profiling ~project_ctx ~project_root ~enabled_rules
    analyze_set =
  let file_rules = List.filter Rule.is_direct_file_scoped enabled_rules in
  let pass_rules = List.filter Rule.uses_pass enabled_rules in
  Eio.Switch.run @@ fun sw ->
  let project_promise, project_resolver = Eio.Promise.create () in
  let file_promise, file_resolver = Eio.Promise.create () in
  Eio.Fiber.fork ~sw (fun () ->
      run_project_rules ?pool ?profiling enabled_rules project_ctx
      |> Eio.Promise.resolve project_resolver);
  Eio.Fiber.fork ~sw (fun () ->
      analyze_files ?pool ~project_ctx ~project_root ~file_rules ~pass_rules
        ?profiling analyze_set
      |> Eio.Promise.resolve file_resolver);
  (Eio.Promise.await project_promise, Eio.Promise.await file_promise)

let build_result ?(bail = false) ?(unchecked_files = [])
    (project_issues, project_excluded) file_results files_analyzed =
  let file_issues = List.concat_map fst file_results in
  let file_excluded = List.concat_map snd file_results in
  let issues = List.sort Rule.Run.compare (project_issues @ file_issues) in
  let issues =
    if bail then match issues with [] -> [] | issue :: _ -> [ issue ]
    else issues
  in
  {
    issues;
    excluded = project_excluded @ file_excluded;
    files_analyzed;
    unchecked_files;
  }

let run ?domain_mgr ~load_file ~filter ?analyze_set ?analyze_roots ~index
    ?profiling ?(bail = false) ?(exclude = []) ?(include_vendored = false)
    project_root =
  Log.info (fun m -> m "Starting analysis of %s" project_root);
  let backend = Merlin.v ~root_dir:project_root () in
  let run_with_pool ?pool () =
    let idx = lazy (index ?pool ()) in
    let idx_value = Lazy.force idx in
    let analyze_set =
      analysis_files ?analyze_set ?analyze_roots ~include_vendored idx_value
      |> drop_excluded_files ~project_root ~exclude
    in
    let file_view = file_view ?profiling ~load_file ~backend in
    let _config, project_ctx, enabled_rules =
      setup_analysis ~filter ~analyze_set ~index:idx ~file_view project_root
    in
    Fs.reset_stats ();
    let files_analyzed = List.length analyze_set in
    let project_results, file_results =
      Probe_events.analysis ~project_root ~files:files_analyzed
        ~rules:(List.length enabled_rules)
      @@ fun () ->
      run_enabled_rules ?pool ?profiling ~project_ctx ~project_root
        ~enabled_rules analyze_set
    in
    log_index_stats idx_value;
    let unchecked_files = log_backend_stats ~index:idx_value backend in
    (project_results, file_results, files_analyzed, unchecked_files)
  in
  Fun.protect
    ~finally:(fun () ->
      log_fs_stats ();
      Merlin.close backend)
    (fun () ->
      let ( (project_issues, project_excluded),
            file_results,
            files_analyzed,
            unchecked_files ) =
        match domain_mgr with
        | None -> run_with_pool ()
        | Some dm -> Fs.with_pool dm (fun pool -> run_with_pool ~pool ())
      in
      build_result ~bail ~unchecked_files
        (project_issues, project_excluded)
        file_results files_analyzed)
