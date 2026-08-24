(** E106: Polymorphic comparison *)

module T = Ocaml_typing.Typedtree
module Types = Ocaml_typing.Types
module Path = Ocaml_typing.Path

type payload = { op : string; advice : string }

(* Built-in types whose representation is transparent, so structural
   comparison on them is well defined. Matched by name because the compiler
   spells them in several ways: the predefined [string], the same type
   qualified through Stdlib, or via the primitive module's [t] (an inferred
   type often becomes [Stdlib.String.t] because String.compare has signature
   [t -> t -> int]). *)
let scalar_names =
  [
    "int";
    "char";
    "string";
    "bytes";
    "float";
    "bool";
    "unit";
    "int32";
    "int64";
    "nativeint";
  ]

let scalar_modules =
  [
    "Int";
    "Char";
    "String";
    "Bytes";
    "Float";
    "Bool";
    "Unit";
    "Int32";
    "Int64";
    "Nativeint";
    "Uchar";
  ]

let container_names = [ "list"; "array"; "option"; "result" ]
let container_modules = [ "List"; "Array"; "Option"; "Result" ]

(* Abstract types whose module registers a correct custom comparison (a C
   [custom_operations] block with [compare]/[compare_ext]/[hash]), so the
   polymorphic operators dispatch to it and are reliable. zarith documents
   this for Z.t and Q.t (reliable since OCaml 3.12.1). There is no static
   signal for the C registration, so this is a curated list. *)
let custom_compare_modules = [ "Z"; "Q" ]

let path_matches path ~names ~modules =
  match String.split_on_char '.' (Path.name path) with
  | [ n ] | [ "Stdlib"; n ] -> List.mem n names
  | [ m; "t" ] | [ "Stdlib"; m; "t" ] -> List.mem m modules
  | _ -> false

let is_scalar path =
  path_matches path ~names:scalar_names ~modules:scalar_modules

let is_container path =
  path_matches path ~names:container_names ~modules:container_modules

let is_custom_compare path =
  path_matches path ~names:[] ~modules:custom_compare_modules

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

(* Walking a value with the polymorphic operators is dangerous only when it can
   reach an abstract type (whose hidden representation the owning module guards
   with its own equal) or a function (which crashes). A type from the current
   module ([Pident]) is visible here and so safe; for another module's type
   ([Pdot]) we read its .cmti and exempt it when its declaration is transparent
   (a public record, variant, or alias). Scalars, transparent containers and
   tuples of those, and type variables are always safe. A polymorphic variant is
   safe only when every present tag's payload is safe: a nullary tag carries
   nothing to walk, but a tag whose payload is a function or an abstract handle
   is as dangerous as that payload. [lib] is the library whose internal short
   sibling references the recursion is currently resolving against (none at the
   top, the cross-module type's own library once we descend into it). [locals]
   holds this file's own module bindings, which have no interface on disk to
   read. *)
let rec dangerous ~root ~locals ~lib ~seen ty =
  match Types.get_desc ty with
  | Types.Tvar _ | Types.Tunivar _ -> false
  | Types.Tarrow _ -> true
  | Types.Ttuple fields ->
      List.exists (fun (_, t) -> dangerous ~root ~locals ~lib ~seen t) fields
  | Types.Tpoly (body, _) -> dangerous ~root ~locals ~lib ~seen body
  | Types.Tvariant row -> dangerous_row ~root ~locals ~lib ~seen row
  | Types.Tconstr (path, args, _) -> (
      if is_scalar path || is_custom_compare path then false
      else if is_container path then
        List.exists (dangerous ~root ~locals ~lib ~seen) args
      else
        match path with
        | Path.Pident _ -> List.exists (dangerous ~root ~locals ~lib ~seen) args
        | _ -> dangerous_named ~root ~locals ~lib ~seen (Path.name path) args)
  | _ -> true

(* A polymorphic variant is dangerous when any present tag carries a payload
   that is itself dangerous. Nullary and absent tags carry nothing to walk. *)
and dangerous_row ~root ~locals ~lib ~seen row =
  List.exists
    (fun (_, field) ->
      match Types.row_field_repr field with
      | Types.Rpresent None | Types.Rabsent -> false
      | Types.Rpresent (Some ty) -> dangerous ~root ~locals ~lib ~seen ty
      | Types.Reither (_, tys, _) ->
          List.exists (dangerous ~root ~locals ~lib ~seen) tys)
    (Types.row_fields row)

(* A type named by another module: dangerous if its declaration is abstract or
   unresolved, or if any type argument or - when transparent - any member is
   itself dangerous. A short sibling name that does not resolve on its own is
   retried as a sub-unit of the enclosing [lib]. Members are resolved against
   the named type's own library (it owns them). [seen] breaks recursion on
   cyclic type definitions. *)
and dangerous_named ~root ~locals ~lib ~seen name args =
  if List.mem name seen then false
  else
    let seen = name :: seen in
    List.exists (dangerous ~root ~locals ~lib ~seen) args
    ||
    match Type_kind.classify ~root ~locals ?lib ~path:name () with
    | Type_kind.Abstract | Type_kind.Unknown -> true
    | Type_kind.Transparent members ->
        let member_lib = Type_kind.library_of ?enclosing:lib name in
        List.exists
          (dangerous ~root ~locals ~lib:(Some member_lib) ~seen)
          members

let flaggable ~root ~locals (operand : T.expression) =
  dangerous ~root ~locals ~lib:None ~seen:[] operand.exp_type

(* The type-specific function the caller should reach for instead. *)
let replacement = function
  | "Hashtbl.hash" | "Hashtbl.seeded_hash" -> "hash"
  | "(=)" | "(<>)" -> "equal"
  | _ -> "compare"

(* Name the function to use, e.g. [Z.equal] for a [Z.t] operand. *)
let advice op (operand : T.expression) =
  match Types.get_desc operand.exp_type with
  | Types.Tarrow _ ->
      "comparing a function value raises Invalid_argument at runtime"
  | Types.Tconstr (path, _, _)
    when (not (is_scalar path)) && not (is_container path) -> (
      match List.rev (String.split_on_char '.' (Path.name path)) with
      | type_name :: (_ :: _ as module_rev) ->
          let m = String.concat "." (List.rev module_rev) in
          let fn = replacement op in
          let fn = if type_name = "t" then fn else fn ^ "_" ^ type_name in
          Fmt.str "use %s.%s instead" m fn
      | _ -> "use the type's own equal, compare or hash instead")
  | _ -> "use the type's own equal, compare or hash instead"

(* Comparing against a constructor whose arguments are themselves tag checks is
   a tag check: a nullary constructor ([], None, an enum tag like [Red]), a
   nullary polymorphic variant tag ([`UDP]), or one wrapping only such ([Ok ()],
   [Some None]). Such a comparison inspects constructor tags and, at deepest, a
   trivially comparable nested tag, never deep or abstract structure -- [x = Ok
   ()] short-circuits on the tag when [x] is [Error _], so an abstract error
   payload is never walked. Leave those alone. *)
let rec is_tag_check (e : T.expression) =
  match e.exp_desc with
  | Texp_construct (_, _, args) -> List.for_all is_tag_check args
  | Texp_variant (_, None) -> true
  | Texp_variant (_, Some arg) -> is_tag_check arg
  | _ -> false

type state = {
  filename : string;
  root : string;
  locals : Type_kind.locals;
  issues : payload Issue.t list ref;
}

let visit_expr state (expr : T.expression) =
  match expr.exp_desc with
  | Texp_apply (fn, args) -> (
      match operator fn with
      | Some op -> (
          let operands = Query.Expr.positional_args args in
          match operands with
          | operand :: _
            when flaggable ~root:state.root ~locals:state.locals operand
                 && not (List.exists is_tag_check operands) ->
              state.issues :=
                Issue.v
                  ~loc:(Loc.of_typed ~filename:state.filename expr.exp_loc)
                  { op; advice = advice op operand }
                :: !(state.issues)
          | _ -> ())
      | None -> ())
  | _ -> ()

let init ctx =
  {
    filename = Context.filename ctx;
    root = Context.project_root_string ctx;
    locals = Type_kind.locals (File_view.typedtree (Context.view ctx));
    issues = ref [];
  }

let finish _ state = List.rev !(state.issues)
let pp ppf { op; advice } = Fmt.pf ppf "Polymorphic %s - %s" op advice

let rule =
  Rule.v ~code:"E106" ~title:"Polymorphic comparison" ~category:Security_safety
    ~hint:
      "OCaml's structural (=), (<>), (<), (>), (<=), (>=), compare, min, max \
       and Hashtbl.hash compare values by walking their runtime \
       representation. On a type from the current module that is fine - you \
       can see its representation, and you expose your own equal in the .mli - \
       but on another module's type it walks past the abstraction (ordering \
       two abstract handles leaks their hidden contents), and on a function it \
       raises Invalid_argument at runtime. Across modules, call that type's \
       own equal, compare or hash. Comparing scalars, transparent containers \
       (list, array, option) and tuples of those is always fine, as is a tag \
       check against a constructor whose payload is itself only tag checks \
       ([], None, an enum tag, a polymorphic variant tag like `UDP, or one \
       wrapping such like Ok () or Some None). Defining a type's own equal or \
       compare with these operators inside its defining module - let equal a b \
       = a = b - is fine and not flagged: there you see the representation and \
       are the authority on whether it is sound."
    ~examples:
      [ Example.bad Examples.E106.bad_ml; Example.good Examples.E106.good_ml ]
    ~pp
    (Rule.pass ~init ~expr:visit_expr ~finish ())
