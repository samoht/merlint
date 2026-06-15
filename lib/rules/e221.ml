(** E221: Disallowed module.

    Bans the use of configured module paths in matching files. The ban list is
    [disallowed_modules] in [merlint.toml]; it is empty by default, so the rule
    is silent until a project opts in. Because merlint merges every
    [merlint.toml] from a file's directory up to the workspace root, the ban is
    naturally scoped: drop a [merlint.toml] carrying
    [disallowed_modules = ["Stdlib.Printf"; "Stdlib.Format"; "Fmt"]] into a
    subtree (for example a [js_of_ocaml] directory) and only the files under it
    are checked.

    Matching is on resolved (typedtree) paths, so a local module that shadows
    [Printf] is not flagged: only a use that genuinely resolves to the banned
    module trips the rule. A configured entry matches a reference when its
    dotted path is a prefix of the reference's resolved path, so [Fmt] bans
    [Fmt.pr] and [Fmt.Dump.list], and [Stdlib.Printf] bans [Printf.printf]. The
    path is fully resolved, so a use reached through [open Fmt] is flagged at
    the call site exactly like a qualified [Fmt.pr]. *)

type payload = { used : string; disallowed : string }

(** [is_prefix short full] is [true] when [short] is an element-wise prefix of
    [full]. *)
let rec is_prefix short full =
  match (short, full) with
  | [], _ -> true
  | _, [] -> false
  | x :: short, y :: full -> x = y && is_prefix short full

(** [banned ~disallowed ref] is the configured entry that bans [ref], if any.
    The reference's resolved path is [prefix @ [base]]; an entry matches when
    its own dotted path is a prefix of that. *)
let banned ~disallowed ref =
  let path =
    File_view.Reference.prefix ref @ [ File_view.Reference.base ref ]
  in
  List.find_opt
    (fun entry -> is_prefix (String.split_on_char '.' entry) path)
    disallowed

let check_references ~disallowed refs =
  List.filter_map
    (fun ref ->
      match (File_view.Reference.loc ref, banned ~disallowed ref) with
      | Some loc, Some disallowed ->
          let used = File_view.Name.to_string (File_view.Reference.name ref) in
          Some (Issue.v ~loc { used; disallowed })
      | _ -> None)
    refs

let check (ctx : Context.file) =
  match ctx.config.disallowed_modules with
  | [] -> []
  | disallowed -> (
      match File_view.resolved_identifiers (Context.view ctx) with
      | None -> []
      | Some identifiers -> check_references ~disallowed identifiers)

let pp ppf { used; disallowed } =
  Fmt.pf ppf
    "%s is disallowed here: module %s is banned by disallowed_modules in \
     merlint.toml."
    used disallowed

let rule =
  Rule.v ~code:"E221" ~title:"Disallowed module"
    ~category:Rule.Style_modernization
    ~hint:
      "This file references a module banned by the [disallowed_modules] list \
       in a merlint.toml that covers it. Use an allowed alternative, or relax \
       the ban for this subtree. The ban is empty by default and scoped to the \
       directory tree of the merlint.toml that declares it, so a subtree that \
       must not depend on Printf/Format/Fmt can forbid them without affecting \
       the rest of the project."
    ~examples:
      [ Example.bad Examples.E221.bad_ml; Example.good Examples.E221.good_ml ]
    ~pp (File check)
