(** E801: Interop test not under test/interop/<tool>/ *)

type payload = { path : string; reason : string }

let known_languages =
  [ "python"; "java"; "go"; "rust"; "c"; "cpp"; "javascript"; "typescript" ]

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs_for ctx in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      (* Check if tool name is a language instead of a tool *)
      if List.mem (String.lowercase_ascii d.tool) known_languages then
        Some
          (Issue.v
             {
               path = Interop.display d;
               reason =
                 Fmt.str
                   "directory named after language %S, should be named after \
                    the oracle tool"
                   d.tool;
             })
      else None)
    dirs

let pp ppf { path; reason } = Fmt.pf ppf "Interop dir %s: %s" path reason

let rule =
  Rule.v ~code:"E801" ~title:"Interop dir named after language"
    ~category:Interop_testing
    ~hint:
      "Interop test directories should be named after the oracle tool (e.g. \
       spacepackets, dariol83, crcmod), not the language (e.g. python, go). \
       This makes it clear which external implementation is the reference."
    ~examples:[] ~pp (Project check)
