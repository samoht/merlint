(** E810: Missing regen-traces alias in dune *)

type payload = { dir : string }

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_dune then
        let content = Interop.dune_content d.path in
        if
          not
            (Astring.String.is_infix ~affix:"regen-traces" content
            || Astring.String.is_infix ~affix:"regen_traces" content)
        then
          let loc = Location.in_file (Filename.concat d.path "dune") in
          Some (Issue.v ~loc { dir = d.path })
        else None
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s/dune missing regen-traces alias" dir

let rule =
  Rule.v ~code:"E810" ~title:"Missing regen-traces alias"
    ~category:Interop_testing
    ~hint:
      "Every interop test dune file must define a regen-traces alias as the \
       single trigger for refreshing traces: `(rule (alias regen-traces) \
       ...)`."
    ~examples:[] ~pp (Project check)
