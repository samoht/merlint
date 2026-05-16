(** E220: Prefer module alias over unconstrained 'module type of' *)

open Ocaml_parsing

type payload = { module_name : string; target : string }

(* Walk the parsetree manually: collect signature items of the form
   [module X : module type of Y] where Y is a simple module path and no
   [with type] / [with module] constraint narrows the signature. Those
   are equivalent to [module X = Y] but heavier — they re-elaborate the
   target signature, and worse, they lose definitional equality on types
   (forcing every reader to remember the alias is opaque). *)

let rec path_of_lid (lid : Longident.t) =
  match lid with
  | Lident s -> Some s
  | Ldot (l, s) -> (
      match path_of_lid l.txt with
      | Some p -> Some (p ^ "." ^ s.txt)
      | None -> None)
  | Lapply _ -> None

(* A [module type of] without [with type t1 = ...] constraints behaves like
   an alias but allocates and loses transparency. With at least one [with]
   clause it's a real signature narrowing — leave alone. *)
let rec is_plain_module_type_of (mty : Parsetree.module_type) =
  match mty.pmty_desc with
  | Pmty_typeof _ -> true
  | Pmty_with (inner, []) -> is_plain_module_type_of inner
  | _ -> false

let target_of_module_type_of (mty : Parsetree.module_type) =
  let rec target (mty : Parsetree.module_type) =
    match mty.pmty_desc with
    | Pmty_typeof mexpr -> (
        match mexpr.pmod_desc with
        | Pmod_ident { txt; _ } -> path_of_lid txt
        | _ -> None)
    | Pmty_with (inner, []) -> target inner
    | _ -> None
  in
  target mty

let collect_issues_signature ~filename signature =
  let issues = ref [] in
  let iter =
    {
      Ast_iterator.default_iterator with
      signature_item =
        (fun this si ->
          (match si.psig_desc with
          | Psig_module md when is_plain_module_type_of md.pmd_type -> (
              match (md.pmd_name.txt, target_of_module_type_of md.pmd_type) with
              | Some name, Some target ->
                  let loc = Ast.merlint_of_loc ~filename si.psig_loc in
                  issues :=
                    Issue.v ~loc { module_name = name; target } :: !issues
              | _ -> ())
          | _ -> ());
          Ast_iterator.default_iterator.signature_item this si);
    }
  in
  iter.signature iter signature;
  List.rev !issues

let check (ctx : Context.file) =
  if not (Filename.check_suffix ctx.filename ".mli") then []
  else
    match File_view.signature (Context.view ctx) with
    | None -> []
    | Some signature ->
        collect_issues_signature ~filename:ctx.filename signature

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
    ~examples:[] ~pp (File check)
