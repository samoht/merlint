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
          match (item.type_sig, Outline.location filename item) with
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

let check (ctx : Context.file) =
  (* Only check .mli files - mutable state in .ml files is fine if not exposed *)
  if not (String.ends_with ~suffix:".mli" ctx.filename) then []
  else
    let outline_data = Context.outline ctx in
    let filename = ctx.filename in
    check_global_mutable_state ~filename outline_data

let pp ppf { kind; name } =
  Fmt.pf ppf
    "Exposed global mutable state '%s' of type '%s' in interface - instead of \
     exposing mutable state, consider providing functions that encapsulate the \
     state manipulation"
    name kind

let rule =
  Rule.v ~code:"E351" ~title:"Exposed Global Mutable State"
    ~category:Security_safety
    ~hint:
      "Exposing global mutable state in interfaces (.mli files) breaks \
       encapsulation and makes programs harder to reason about. Instead of \
       exposing refs or mutable arrays directly, provide functions that \
       encapsulate state manipulation. This preserves module abstraction and \
       makes the API clearer. Internal mutable state in .ml files is fine as \
       long as it's not exposed in the interface."
    ~examples:
      [ Example.bad Examples.E351.bad_ml; Example.good Examples.E351.good_ml ]
    ~pp (File check)
