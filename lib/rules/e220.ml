(** E220: Prefer module alias over unconstrained 'module type of' *)

module T = Ocaml_typing.Typedtree

type payload = { module_name : string; target : string }

(* Walk the typedtree: collect signature items of the form
   [module X : module type of Y] where Y is a simple module path and no
   [with type] / [with module] constraint narrows the signature. Those
   are equivalent to [module X = Y] but heavier — they re-elaborate the
   target signature, and worse, they lose definitional equality on types
   (forcing every reader to remember the alias is opaque). *)

(* A [module type of] without [with type t1 = ...] constraints behaves like
   an alias but allocates and loses transparency. With at least one [with]
   clause it's a real signature narrowing — leave alone. *)
let rec is_plain_module_type_of (mty : T.module_type) =
  match mty.mty_desc with
  | Tmty_typeof _ -> true
  | Tmty_with (inner, []) -> is_plain_module_type_of inner
  | _ -> false

let target_of_module_type_of (mty : T.module_type) =
  let rec target (mty : T.module_type) =
    match mty.mty_desc with
    | Tmty_typeof mexpr -> (
        match mexpr.mod_desc with
        | Tmod_ident (path, _) ->
            Some (String.concat "." (Query.Path.parts path))
        | _ -> None)
    | Tmty_with (inner, []) -> target inner
    | _ -> None
  in
  target mty

type state = {
  filename : string;
  enabled : bool;
  issues : payload Issue.t list ref;
}

let visit_signature_item state (si : T.signature_item) =
  if state.enabled then
    match si.sig_desc with
    | Tsig_module md when is_plain_module_type_of md.md_type -> (
        match (md.md_name.txt, target_of_module_type_of md.md_type) with
        | Some name, Some target ->
            let loc = Loc.of_typed ~filename:state.filename si.sig_loc in
            state.issues :=
              Issue.v ~loc { module_name = name; target } :: !(state.issues)
        | _ -> ())
    | _ -> ()

let select ctx = Filename.check_suffix (Context.filename ctx) ".mli"

let init ctx =
  let filename = Context.filename ctx in
  { filename; enabled = true; issues = ref [] }

let finish _ state = List.rev !(state.issues)

let pp ppf { module_name; target } =
  Fmt.pf ppf
    "[module %s : module type of %s] without [with type] constraints — replace \
     with [module %s = %s] (cheaper to elaborate, preserves definitional \
     equality)."
    module_name target module_name target

let rule =
  Rule.v ~code:"E220" ~title:"Prefer module alias over unconstrained typeof"
    ~category:Style_modernization
    ~hint:
      "[module X : module type of Y] re-elaborates the target signature and \
       hides type equalities behind a fresh abstraction; an alias [module X = \
       Y] is cheaper to typecheck and preserves equalities. Keep [module type \
       of] only when you immediately narrow with [with type t = ...] / [with \
       module M = ...]."
    ~examples:[] ~pp
    (Rule.pass ~select ~init ~signature_item:visit_signature_item ~finish ())
