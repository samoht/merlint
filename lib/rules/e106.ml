(** E106: Polymorphic comparison *)

module T = Ocaml_typing.Typedtree
module Types = Ocaml_typing.Types
module Path = Ocaml_typing.Path
module Predef = Ocaml_typing.Predef
module Env = Ocaml_typing.Env

type payload = { op : string }

(* Scalars have a single, unambiguous structural comparison; polymorphic
   comparison on them is monomorphic and safe. *)
let scalar_paths =
  [
    Predef.path_int;
    Predef.path_char;
    Predef.path_string;
    Predef.path_bytes;
    Predef.path_float;
    Predef.path_bool;
    Predef.path_unit;
    Predef.path_int32;
    Predef.path_int64;
    Predef.path_nativeint;
  ]

(* Stdlib operators that compare or hash by walking the runtime
   representation, keyed by their resolved path. *)
let poly_ops =
  [
    ([ "Stdlib"; "=" ], "(=)");
    ([ "Stdlib"; "<>" ], "(<>)");
    ([ "Stdlib"; "<" ], "(<)");
    ([ "Stdlib"; ">" ], "(>)");
    ([ "Stdlib"; "<=" ], "(<=)");
    ([ "Stdlib"; ">=" ], "(>=)");
    ([ "Stdlib"; "compare" ], "compare");
    ([ "Stdlib"; "min" ], "min");
    ([ "Stdlib"; "max" ], "max");
    ([ "Stdlib"; "Hashtbl"; "hash" ], "Hashtbl.hash");
    ([ "Stdlib"; "Hashtbl"; "seeded_hash" ], "Hashtbl.seeded_hash");
  ]

let operator fn =
  match Query.Expr.callee_parts fn with
  | None -> None
  | Some parts -> List.assoc_opt parts poly_ops

let container_paths =
  [ Predef.path_list; Predef.path_array; Predef.path_option ]

let constructor_arg_types (cd : Types.constructor_declaration) =
  match cd.cd_args with
  | Types.Cstr_tuple types -> types
  | Types.Cstr_record labels ->
      List.map (fun (l : Types.label_declaration) -> l.ld_type) labels

(* Walking a value's runtime representation is dangerous only if it can reach
   an abstract type (whose representation is meant to be hidden), a function
   (which crashes), or a private type (whose equality is its own business).
   Scalars and transparent records, variants, tuples and containers built
   from safe types carry no such hazard. A type variable is generic: whoever
   instantiates it owns the choice, so it is left alone here. [seen] breaks
   recursion on cyclic type definitions. *)
let rec dangerous ~env ~seen ty =
  match Types.get_desc ty with
  | Types.Tvar _ | Types.Tunivar _ -> false
  | Types.Tarrow _ -> true
  | Types.Ttuple fields ->
      List.exists (fun (_, t) -> dangerous ~env ~seen t) fields
  | Types.Tpoly (body, _) -> dangerous ~env ~seen body
  | Types.Tconstr (path, args, _) ->
      if List.exists (Path.same path) scalar_paths then false
      else if List.exists (Path.same path) container_paths then
        List.exists (dangerous ~env ~seen) args
      else if List.exists (Path.same path) seen then false
      else
        let seen = path :: seen in
        (* A dangerous type argument taints the whole value. *)
        List.exists (dangerous ~env ~seen) args
        ||
        (match Env.find_type path env with
        | exception Not_found -> true
        | decl -> (
            match decl.Types.type_private with
            | Ocaml_parsing.Asttypes.Private -> true
            | Ocaml_parsing.Asttypes.Public -> (
                match (decl.type_kind, decl.type_manifest) with
                | _, Some manifest -> dangerous ~env ~seen manifest
                | Types.Type_record (labels, _), None ->
                    List.exists
                      (fun (l : Types.label_declaration) ->
                        dangerous ~env ~seen l.ld_type)
                      labels
                | Types.Type_variant (cstrs, _), None ->
                    List.exists
                      (fun cd ->
                        List.exists (dangerous ~env ~seen)
                          (constructor_arg_types cd))
                      cstrs
                | Types.Type_abstract _, None | Types.Type_open, None -> true)))
  | _ -> true

let flaggable (operand : T.expression) =
  dangerous ~env:operand.exp_env ~seen:[] operand.exp_type

(* Comparing against a nullary constructor ([], None, an enum tag like
   [Red]) is a tag check: it inspects the constructor, not deep structure, so
   it is safe and idiomatic. Leave those alone. *)
let is_tag_check (e : T.expression) =
  match e.exp_desc with Texp_construct (_, _, []) -> true | _ -> false

type state = { filename : string; issues : payload Issue.t list ref }

let visit_expr state (expr : T.expression) =
  match expr.exp_desc with
  | Texp_apply (fn, args) -> (
      match operator fn with
      | Some op -> (
          let operands = Query.Expr.positional_args args in
          match operands with
          | operand :: _
            when flaggable operand
                 && not (List.exists is_tag_check operands) ->
              state.issues :=
                Issue.v
                  ~loc:(Loc.of_typed ~filename:state.filename expr.exp_loc)
                  { op }
                :: !(state.issues)
          | _ -> ())
      | None -> ())
  | _ -> ()

let init ctx = { filename = Context.filename ctx; issues = ref [] }
let finish _ state = List.rev !(state.issues)

let pp ppf { op } =
  Fmt.pf ppf
    "Polymorphic %s used on a non-scalar type - use the type's own \
     equal/compare/hash instead"
    op

let rule =
  Rule.v ~code:"E106" ~title:"Polymorphic comparison" ~category:Security_safety
    ~hint:
      "OCaml's structural (=), (<>), (<), (>), (<=), (>=), compare, min, max \
       and Hashtbl.hash compare values by walking their runtime \
       representation. That is dangerous when the value can hold an abstract \
       type (the walk reaches through the abstraction boundary the module set \
       up - e.g. ordering two abstract handles leaks their hidden contents), \
       a function (which raises Invalid_argument at runtime), or a private \
       type (whose equality is its own business). Call the type's own equal, \
       compare or hash instead - every type module should expose them - and \
       have a genuinely generic function take an ~equal or ~compare \
       parameter. Comparing scalars and transparent records, variants, tuples \
       and containers built only from safe types is fine, and so is comparing \
       against a nullary constructor ([], None, an enum tag)."
    ~examples:
      [ Example.bad Examples.E106.bad_ml; Example.good Examples.E106.good_ml ]
    ~pp
    (Rule.pass ~init ~expr:visit_expr ~finish ())
