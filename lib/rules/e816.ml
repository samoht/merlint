(** E816: Interop generate.sh ignores its output-dir argument *)

type payload = { dir : string }

(* generate.sh must accept the output directory as its first argument so the
   regen rule can run it with the build trace dir as $1. A script that hardcodes
   ../traces writes to the wrong (read-only, sandboxed) place. *)
let takes_output_dir scripts =
  Interop.script_contains ~dir:scripts ~file:"generate.sh" ~affix:"$1"
  || Interop.script_contains ~dir:scripts ~file:"generate.sh" ~affix:"${1"

let issue_for_oracle (d : Interop.oracle_dir) =
  let scripts = Path.(d.path / "scripts") |> Context.string_of_path in
  let gen = Filename.concat scripts "generate.sh" in
  if (not (Fs.file_exists gen)) || takes_output_dir scripts then None
  else
    let loc = Location.in_file gen in
    Some (Issue.v ~loc { dir = Interop.display d })

let check (ctx : Context.project) =
  Interop.oracle_dirs_for ctx |> List.filter_map issue_for_oracle

let pp ppf { dir } =
  Fmt.pf ppf "%s/scripts/generate.sh ignores its output-dir argument ($1)" dir

let rule =
  Rule.v ~code:"E816" ~title:"generate.sh ignores output-dir argument"
    ~category:Interop_testing
    ~hint:
      "scripts/generate.sh must take the output directory as its first \
       argument, e.g. `TRACE_DIR=\"$(cd \"${1:-$SCRIPT_DIR/../traces}\" && \
       pwd)\"`. The traces/dune regen rule runs it with the build trace dir as \
       $1; a script that hardcodes ../traces writes to the wrong place."
    ~examples:[] ~pp (Project check)
