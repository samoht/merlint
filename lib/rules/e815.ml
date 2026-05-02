(** E815: REGEN_TRACES sentinel in dune *)

type payload = { dir : string }

let check (ctx : Context.project) =
  let dirs = Interop.find_oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_dune then
        let content = Interop.dune_content d.path in
        if Astring.String.is_infix ~affix:"REGEN_TRACES" content then
          let loc = Location.in_file (Filename.concat d.path "dune") in
          Some (Issue.v ~loc { dir = d.path })
        else None
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s/dune uses REGEN_TRACES sentinel" dir

let rule =
  Rule.v ~code:"E815" ~title:"REGEN_TRACES sentinel in dune"
    ~category:Interop_testing
    ~hint:
      "The regen-traces alias should be the single entry point — no \
       REGEN_TRACES=1 env var sentinel. Remove the (enabled_if ...) guard so \
       `dune build @regen-traces` works directly."
    ~examples:[] ~pp (Project check)
