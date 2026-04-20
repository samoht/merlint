(** E351: Detection of global mutable state patterns.

    Walks the {!Ocaml_typing.Typedtree.signature} produced from the [.cmti]
    and checks every [Sig_value] whose {!Ocaml_typing.Types.type_expr} head
    resolves to [Predef.path_array] or [Predef.path_ref].  Because the
    check is on the fully-resolved {!Ocaml_typing.Path.t}, local type
    definitions that happen to be called [ref] or [array] do {e not}
    shadow the rule: only actual [Stdlib.array]/[Stdlib.ref] values are
    flagged. *)

type payload = { kind : string; name : string }
(** Payload for mutable state issues *)

module Types = Ocaml_typing.Types
module Typedtree = Ocaml_typing.Typedtree
module Path = Ocaml_typing.Path
module Predef = Ocaml_typing.Predef

let is_stdlib_ref p =
  (* [ref] is not a predef -- it's a regular record type in [Stdlib], so
     we compare against the qualified name directly. *)
  let n = Path.name p in
  n = "ref" || n = "Stdlib.ref"

let mutable_kind_of_type_expr te =
  (* [Types.get_desc] unwraps [Tlink]s and other indirections without
     forcing an environment; the head constructor is what we need. *)
  match Types.get_desc te with
  | Tconstr (p, _, _) when Path.same p Predef.path_array -> Some "array"
  | Tconstr (p, _, _) when is_stdlib_ref p -> Some "ref"
  | _ -> None

let location_of_cmt (loc : Ocaml_utils.Warnings.loc) =
  let loc_start = loc.loc_start and loc_end = loc.loc_end in
  Merlin.Location.v ~file:loc_start.Lexing.pos_fname
    ~start_line:loc_start.Lexing.pos_lnum
    ~start_col:(loc_start.Lexing.pos_cnum - loc_start.Lexing.pos_bol)
    ~end_line:loc_end.Lexing.pos_lnum
    ~end_col:(loc_end.Lexing.pos_cnum - loc_end.Lexing.pos_bol)

let check_signature (signature : Typedtree.signature) =
  List.filter_map
    (fun (item : Typedtree.signature_item) ->
      match item.sig_desc with
      | Tsig_value vd -> (
          match mutable_kind_of_type_expr vd.val_val.val_type with
          | None -> None
          | Some kind ->
              let loc = location_of_cmt vd.val_loc in
              Some (Issue.v ~loc { kind; name = vd.val_name.txt }))
      | _ -> None)
    signature.sig_items

let check (ctx : Context.file) =
  if not (String.ends_with ~suffix:".mli" ctx.filename) then []
  else
    match Context.cmt ctx with
    | Some { cmt_annots = Interface signature; _ } ->
        check_signature signature
    | _ -> []

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
