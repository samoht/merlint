(** Linting engine *)

let src = Logs.Src.create "merlint.engine" ~doc:"Linting engine"

module Log = (val Logs.src_log src : Logs.LOG)
module T = Ocaml_typing.Typedtree
module Tast_iterator = Ocaml_typing.Tast_iterator

type exclusion_stats = { rule : string; file : string }
type result = { issues : Rule.Run.result list; excluded : exclusion_stats list }

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

let log_backend_stats backend =
  let s = Merlin.stats backend in
  Log.info (fun m ->
      m "Merlin stats: cmt_hits=%d cmt_misses=%d cmt_reads=%d source_parses=%d"
        s.cmt_hits s.cmt_misses s.cmt_reads s.source_parses);
  warn_missing_cmts s.cmt_misses

let run_file_rule ?profiling ctx rule =
  let code = Rule.code rule in
  Log.debug (fun m -> m "Running rule %s on %s" code ctx.Context.filename);
  let start_time = Unix.gettimeofday () in
  let res =
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

let source_filename filename =
  let file = Fpath.v filename in
  if Fpath.is_abs file then Fpath.to_string (Fpath.normalize file)
  else Fpath.(v (Sys.getcwd ()) // file |> normalize |> to_string)

let file_view ?profiling ~load_file ~backend filename =
  let source_filename = source_filename filename in
  let content = lazy (load_file source_filename) in
  let source = Merlin.Source.v ~file:source_filename ~content in
  let typedtree () =
    merlin_op ?profiling filename (fun () -> Merlin.typedtree backend ~source)
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

let run_passes passes ctx =
  match passes with
  | [] -> []
  | _ -> (
      match File_view.typedtree (Context.view ctx) with
      | None -> []
      | Some tree ->
          let on_attribute = List.filter_map Rule.Run.pass_attribute passes in
          let on_expr = List.filter_map Rule.Run.pass_expr passes in
          let on_value_binding =
            List.filter_map Rule.Run.pass_value_binding passes
          in
          let on_structure_item =
            List.filter_map Rule.Run.pass_structure_item passes
          in
          let on_signature_item =
            List.filter_map Rule.Run.pass_signature_item passes
          in
          let dispatch_expr expr = List.iter (fun f -> f expr) on_expr in
          let dispatch_value_binding value_binding =
            List.iter (fun f -> f value_binding) on_value_binding
          in
          let dispatch_structure_item item =
            List.iter (fun f -> f item) on_structure_item
          in
          let dispatch_signature_item item =
            List.iter (fun f -> f item) on_signature_item
          in
          let dispatch_attribute attr =
            List.iter (fun f -> f attr) on_attribute
          in
          let iterator =
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
                  Tast_iterator.default_iterator.value_binding this
                    value_binding);
            }
          in
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
  let results =
    match pool with
    | None -> List.map run jobs
    | Some pool -> Fs.parallel_map pool jobs run
  in
  let issues = List.concat_map fst results in
  let excluded = List.concat_map snd results in
  (issues, excluded)

let analyze_single_file ?profiling ~project_ctx ~config_for ~project_root
    ~file_rules ~pass_rules filepath =
  let filename = Fpath.to_string filepath in
  let config = config_for filename in
  let excluded_acc = ref [] in
  let issues =
    try
      ignore profiling;
      let view = Context.file_view project_ctx filename in
      let file_ctx =
        Context.file_with_view ~filename ~config ~project_root ~view
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

(** Walk [files] in parallel across [domain_mgr]'s executor pool. Each file is
    its own work unit; the pool decides how to spread them across domains. The
    earlier per-package grouping protected a process-global compiler-libs state
    that [typedtree_from_cmt] hasn't touched since the [with_cmt_state] wrap was
    removed -- cmt loading is now pure [Marshal.from_channel] and safe to call
    concurrently from any domain. *)
let analyze_files ?pool ~project_ctx ~project_root ~file_rules ~pass_rules
    ?profiling files =
  let config_for = config_lookup () in
  let analyse filepath =
    analyze_single_file ?profiling ~project_ctx ~config_for ~project_root
      ~file_rules ~pass_rules filepath
  in
  match pool with
  | None -> List.map analyse files
  | Some pool -> Fs.parallel_map pool files analyse

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
  let raw_analyze_set =
    match analyze_set with
    | Some files -> files
    | None -> Dune_describe.project_files dune_describe
  in
  let run_with_pool ?pool () =
    let idx = lazy (index ?pool ()) in
    let analyze_set = drop_vendored_files (Lazy.force idx) raw_analyze_set in
    let file_view = file_view ?profiling ~load_file ~backend in
    let _config, project_ctx, enabled_rules =
      setup_analysis ~filter ~dune_describe ~analyze_set ~index:idx ~file_view
        project_root
    in
    Fs.reset_stats ();
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
  in
  Fun.protect
    ~finally:(fun () ->
      log_backend_stats backend;
      log_fs_stats ();
      Merlin.close backend)
    (fun () ->
      let (project_issues, project_excluded), file_results =
        match domain_mgr with
        | None -> run_with_pool ()
        | Some dm -> Fs.with_pool dm (fun pool -> run_with_pool ~pool ())
      in
      let file_issues = List.concat_map fst file_results in
      let file_excluded = List.concat_map snd file_results in
      {
        issues = List.sort Rule.Run.compare (project_issues @ file_issues);
        excluded = project_excluded @ file_excluded;
      })
