(** E351: Detection of global mutable state patterns *)

type payload = { kind : string; name : string }
(** Payload for mutable state issues *)

(* Precompiled regexes for efficiency *)
let ref_type_re = Re.compile (Re.alt [ Re.str " ref"; Re.str "= ref" ])
let array_type_re = Re.compile (Re.str " array")

(** Check if a type signature indicates mutable state *)
let is_mutable_type type_sig =
  (* Skip function types that return refs/arrays *)
  if Re.execp (Re.compile (Re.str "->")) type_sig then false
  else
    (* Check for ref types - look for patterns like "int ref" or "= ref" *)
    Re.execp ref_type_re type_sig
    (* Check for array types *)
    || Re.execp array_type_re type_sig
    ||
    (* Check for mutable record fields - this is harder to detect from type sig *)
    false

(** Check outline for global mutable state *)
let check_global_mutable_state ~filename outline =
  List.filter_map
    (fun item ->
      match item.Outline.kind with
      | Outline.Value -> (
          match
            (item.type_sig, Helpers.extract_outline_location filename item)
          with
          | Some type_sig, Some location when is_mutable_type type_sig ->
              let kind =
                if Re.execp ref_type_re type_sig then "ref"
                else if Re.execp array_type_re type_sig then "array"
                else "mutable"
              in
              Some (Issue.v ~loc:location { kind; name = item.name })
          | _ -> None)
      | _ -> None)
    outline

(** Check for local mutable state usage (refs created inside functions) This is
    more complex and would require AST analysis *)
let _check_local_mutable_state ~filename:_ _typedtree =
  (* TODO: This would need deeper AST analysis to determine scope
     For now, we only check global state via outline *)
  []

let check ctx =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  check_global_mutable_state ~filename outline_data

let pp ppf { kind; name } =
  Fmt.pf ppf
    "Global mutable state '%s' of type '%s' detected - consider using \
     functional patterns instead"
    name kind

let rule =
  Rule.v ~code:"E351" ~title:"Global Mutable State" ~category:Security_safety
    ~hint:
      "Global mutable state makes programs harder to reason about and test. \
       Consider using immutable data structures and passing state explicitly \
       through function parameters. If mutation is necessary, consider using \
       local state within functions or monadic patterns."
    ~examples:[] ~pp (File check)
