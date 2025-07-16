(** Detection of global mutable state patterns *)

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
  let issues = ref [] in

  List.iter
    (fun item ->
      match item.Outline.kind with
      | Outline.Value -> (
          match (item.type_sig, item.range) with
          | Some type_sig, Some range when is_mutable_type type_sig ->
              let location =
                Location.create ~file:filename ~start_line:range.start.line
                  ~start_col:range.start.col ~end_line:range.end_.line
                  ~end_col:range.end_.col
              in
              let kind =
                if Re.execp ref_type_re type_sig then "ref"
                else if Re.execp array_type_re type_sig then "array"
                else "mutable"
              in
              issues :=
                Issue.Mutable_state { kind; name = item.name; location }
                :: !issues
          | _ -> ())
      | _ -> ())
    outline;

  !issues

(** Check for local mutable state usage (refs created inside functions) This is
    more complex and would require AST analysis *)
let _check_local_mutable_state ~filename:_ _typedtree =
  (* TODO: This would need deeper AST analysis to determine scope
     For now, we only check global state via outline *)
  []

let check (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  check_global_mutable_state ~filename outline_data
