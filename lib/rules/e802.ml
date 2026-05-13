(** E802: Interop test missing committed traces *)

type payload = { dir : string; reason : string }

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if not d.has_traces then
        Some
          (Issue.v
             {
               dir = d.path;
               reason = "missing traces/ directory — traces must be committed";
             })
      else if d.has_dune then
        let dune = Interop.dune_content d.path in
        if not (Astring.String.is_infix ~affix:"source_tree traces" dune) then
          Some
            (Issue.v
               {
                 dir = d.path;
                 reason =
                   "dune test stanza missing (source_tree traces) dep — test \
                    must run from committed traces";
               })
        else None
      else None)
    dirs

let pp ppf { dir; reason } = Fmt.pf ppf "Interop test %s: %s" dir reason

let rule =
  Rule.v ~code:"E802" ~title:"Interop test not replay-only"
    ~category:Interop_testing
    ~hint:
      "Traces must be committed to git. The test stanza must depend on \
       (source_tree traces) so tests run from traces alone — the external tool \
       is NOT required at test time. This is the 'generate once, replay \
       always' principle."
    ~examples:[] ~pp (Project check)
