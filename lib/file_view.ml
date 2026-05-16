let src = Logs.Src.create "merlint.file_view" ~doc:"File view"

module Log = (val Logs.src_log src : Logs.LOG)
module Compiler_parsetree = Parsetree
module Compiler_pprintast = Pprintast
module Typedtree = Ocaml_typing.Typedtree
module Tast_iterator = Ocaml_typing.Tast_iterator
module Typed_ident = Ocaml_typing.Ident
module Typed_path = Ocaml_typing.Path
open Ocaml_parsing

exception Analysis_error of string

let fail fmt = Fmt.kstr (fun s -> raise (Analysis_error s)) fmt

let name_of_parts = function
  | [] -> { Merlin.Refs.prefix = []; base = "" }
  | parts ->
      let rev = List.rev parts in
      { Merlin.Refs.prefix = List.rev (List.tl rev); base = List.hd rev }

let name_of_string_path path =
  path |> String.split_on_char '.'
  |> List.filter (fun s -> s <> "")
  |> name_of_parts

let name_of_path path =
  match Typed_path.flatten path with
  | `Ok (base, suffix) -> name_of_parts (Typed_ident.name base :: suffix)
  | `Contains_apply -> name_of_string_path (Typed_path.name path)

let name_of_ident ident = name_of_parts [ Typed_ident.name ident ]

let name_of_longident lid =
  let rec parts acc = function
    | Longident.Lident s -> s :: acc
    | Ldot (prefix, s) -> parts (s.txt :: acc) prefix.txt
    | Lapply _ -> acc
  in
  name_of_parts (parts [] lid)

let loc_of_typed_loc ~filename loc =
  if loc.Location.loc_ghost then None
  else Some (Ast.merlint_of_loc ~filename loc)

let elt_of_name ~filename name loc =
  { Merlin.Refs.name; location = loc_of_typed_loc ~filename loc }

let elt_of_path ~filename path loc =
  elt_of_name ~filename (name_of_path path) loc

let elt_of_ident ~filename ident loc =
  elt_of_name ~filename (name_of_ident ident) loc

let elt_of_longident ~filename (lid : Longident.t Asttypes.loc) loc =
  elt_of_name ~filename (name_of_longident lid.txt) loc

let push r x = r := x :: !r

type collected_refs = {
  refs : Merlin.Refs.t;
  variant_definitions : Merlin.Refs.elt list;
  module_definitions : Merlin.Refs.elt list;
  type_definitions : Merlin.Refs.elt list;
}

type refs_acc = {
  modules : Merlin.Refs.elt list ref;
  module_definitions : Merlin.Refs.elt list ref;
  types : Merlin.Refs.elt list ref;
  type_definitions : Merlin.Refs.elt list ref;
  exceptions : Merlin.Refs.elt list ref;
  variants : Merlin.Refs.elt list ref;
  variant_definitions : Merlin.Refs.elt list ref;
  identifiers : Merlin.Refs.elt list ref;
  patterns : Merlin.Refs.elt list ref;
  values : Merlin.Refs.elt list ref;
  value_sigs : Merlin.Refs.value_sig list ref;
}

let refs_acc () =
  {
    modules = ref [];
    module_definitions = ref [];
    types = ref [];
    type_definitions = ref [];
    exceptions = ref [];
    variants = ref [];
    variant_definitions = ref [];
    identifiers = ref [];
    patterns = ref [];
    values = ref [];
    value_sigs = ref [];
  }

let empty_refs =
  {
    refs =
      {
        Merlin.Refs.modules = [];
        types = [];
        exceptions = [];
        variants = [];
        identifiers = [];
        patterns = [];
        values = [];
        value_sigs = [];
      };
    variant_definitions = [];
    module_definitions = [];
    type_definitions = [];
  }

let collected_refs_of_acc acc =
  {
    refs =
      {
        Merlin.Refs.modules = List.rev !(acc.modules);
        types = List.rev !(acc.types);
        exceptions = List.rev !(acc.exceptions);
        variants = List.rev !(acc.variants);
        identifiers = List.rev !(acc.identifiers);
        patterns = List.rev !(acc.patterns);
        values = List.rev !(acc.values);
        value_sigs = List.rev !(acc.value_sigs);
      };
    variant_definitions = List.rev !(acc.variant_definitions);
    module_definitions = List.rev !(acc.module_definitions);
    type_definitions = List.rev !(acc.type_definitions);
  }

let add_local ~filename target name loc =
  push target (elt_of_name ~filename (name_of_parts [ name ]) loc)

let add_path ~filename target (lid : Longident.t Asttypes.loc) loc =
  push target (elt_of_name ~filename (name_of_longident lid.txt) loc)

let add_definition target definitions elt =
  push target elt;
  push definitions elt

let add_named_definition ~filename target definitions name loc =
  let elt = elt_of_name ~filename (name_of_parts [ name ]) loc in
  add_definition target definitions elt

let iter_parsetree_expr ~filename acc this (expr : Parsetree.expression) =
  (match expr.pexp_desc with
  | Pexp_ident lid -> add_path ~filename acc.identifiers lid expr.pexp_loc
  | Pexp_construct (lid, _) -> add_path ~filename acc.variants lid expr.pexp_loc
  | _ -> ());
  Ast_iterator.default_iterator.expr this expr

let iter_parsetree_pat ~filename acc this (pat : Parsetree.pattern) =
  (match pat.ppat_desc with
  | Ppat_var name ->
      add_local ~filename acc.patterns name.txt name.loc;
      add_local ~filename acc.values name.txt name.loc
  | Ppat_construct (lid, _) -> add_path ~filename acc.variants lid pat.ppat_loc
  | Ppat_exception p -> Ast_iterator.default_iterator.pat this p
  | _ -> ());
  Ast_iterator.default_iterator.pat this pat

let iter_parsetree_module_expr ~filename acc this
    (mexpr : Parsetree.module_expr) =
  (match mexpr.pmod_desc with
  | Pmod_ident lid -> add_path ~filename acc.modules lid mexpr.pmod_loc
  | _ -> ());
  Ast_iterator.default_iterator.module_expr this mexpr

let iter_parsetree_module_binding ~filename acc this
    (mb : Parsetree.module_binding) =
  Option.iter
    (fun name ->
      add_named_definition ~filename acc.modules acc.module_definitions name
        mb.pmb_name.loc)
    mb.pmb_name.txt;
  Ast_iterator.default_iterator.module_binding this mb

let iter_parsetree_type_declaration ~filename acc this
    (decl : Parsetree.type_declaration) =
  add_named_definition ~filename acc.types acc.type_definitions
    decl.ptype_name.txt decl.ptype_name.loc;
  Ast_iterator.default_iterator.type_declaration this decl

let iter_parsetree_constructor_declaration ~filename acc this
    (cd : Parsetree.constructor_declaration) =
  add_named_definition ~filename acc.variants acc.variant_definitions
    cd.pcd_name.txt cd.pcd_name.loc;
  Ast_iterator.default_iterator.constructor_declaration this cd

let iter_parsetree_extension_constructor ~filename acc this
    (ext : Parsetree.extension_constructor) =
  add_named_definition ~filename acc.variants acc.variant_definitions
    ext.pext_name.txt ext.pext_name.loc;
  Ast_iterator.default_iterator.extension_constructor this ext

let iter_parsetree_type_exception ~filename acc this
    (exn : Parsetree.type_exception) =
  add_local ~filename acc.exceptions exn.ptyexn_constructor.pext_name.txt
    exn.ptyexn_constructor.pext_name.loc;
  Ast_iterator.default_iterator.type_exception this exn

let collect_parsetree_outline ~filename (structure : Parsetree.structure) =
  let acc = refs_acc () in
  let iterator =
    {
      Ast_iterator.default_iterator with
      expr = iter_parsetree_expr ~filename acc;
      pat = iter_parsetree_pat ~filename acc;
      module_expr = iter_parsetree_module_expr ~filename acc;
      module_binding = iter_parsetree_module_binding ~filename acc;
      type_declaration = iter_parsetree_type_declaration ~filename acc;
      constructor_declaration =
        iter_parsetree_constructor_declaration ~filename acc;
      extension_constructor = iter_parsetree_extension_constructor ~filename acc;
      type_exception = iter_parsetree_type_exception ~filename acc;
    }
  in
  iterator.structure iterator structure;
  collected_refs_of_acc acc

let rec pattern_value_names : type k.
    filename:string -> k Typedtree.general_pattern -> Merlin.Refs.elt list =
 fun ~filename pat ->
  let rest =
    match pat.pat_desc with
    | Tpat_alias (p, ident, loc, _, _) ->
        elt_of_ident ~filename ident loc.loc :: pattern_value_names ~filename p
    | Tpat_tuple fields ->
        List.concat_map (fun (_, p) -> pattern_value_names ~filename p) fields
    | Tpat_construct (_, _, args, _) ->
        List.concat_map (pattern_value_names ~filename) args
    | Tpat_variant (_, arg, _) -> (
        match arg with None -> [] | Some p -> pattern_value_names ~filename p)
    | Tpat_record (fields, _) ->
        List.concat_map
          (fun (_, _, p) -> pattern_value_names ~filename p)
          fields
    | Tpat_array (_, pats) ->
        List.concat_map (pattern_value_names ~filename) pats
    | Tpat_or (lhs, rhs, _) ->
        pattern_value_names ~filename lhs @ pattern_value_names ~filename rhs
    | Tpat_lazy p | Tpat_exception p -> pattern_value_names ~filename p
    | Tpat_value _ -> []
    | Tpat_var (ident, loc, _) -> [ elt_of_ident ~filename ident loc.loc ]
    | Tpat_any | Tpat_constant _ -> []
  in
  rest

let type_path_of_core_type (ct : Typedtree.core_type) =
  match ct.ctyp_desc with
  | Ttyp_constr (path, _, _) -> Some (name_of_path path)
  | _ -> None

let add_typed_module_ident ~filename acc id loc =
  Option.iter
    (fun id ->
      let elt = elt_of_ident ~filename id loc in
      add_definition acc.modules acc.module_definitions elt)
    id

let add_value_sig ~filename acc (vd : Typedtree.value_description) =
  let name = (elt_of_ident ~filename vd.val_id vd.val_name.loc).name in
  push acc.value_sigs
    {
      Merlin.Refs.name;
      location = loc_of_typed_loc ~filename vd.val_loc;
      type_path = type_path_of_core_type vd.val_desc;
    }

let iter_typed_expr ~filename acc this (expr : Typedtree.expression) =
  (match expr.exp_desc with
  | Texp_ident (path, _, _) ->
      push acc.identifiers (elt_of_path ~filename path expr.exp_loc)
  | Texp_construct (lid, _, _) ->
      push acc.variants (elt_of_longident ~filename lid lid.loc)
  | _ -> ());
  Tast_iterator.default_iterator.expr this expr

let iter_typed_pat ~filename acc (type k) this
    (pat : k Typedtree.general_pattern) =
  (match pat.pat_desc with
  | Tpat_var (ident, loc, _) ->
      push acc.patterns (elt_of_ident ~filename ident loc.loc)
  | Tpat_construct (lid, _, _, _) ->
      push acc.variants (elt_of_longident ~filename lid lid.loc)
  | Tpat_variant (label, _, _) ->
      push acc.variants
        (elt_of_name ~filename (name_of_parts [ label ]) pat.pat_loc)
  | _ -> ());
  Tast_iterator.default_iterator.pat this pat

let iter_typed_typ ~filename acc this (typ : Typedtree.core_type) =
  (match typ.ctyp_desc with
  | Ttyp_constr (path, _, _) ->
      push acc.types (elt_of_path ~filename path typ.ctyp_loc)
  | _ -> ());
  Tast_iterator.default_iterator.typ this typ

let iter_typed_module_expr ~filename acc this (mexpr : Typedtree.module_expr) =
  (match mexpr.mod_desc with
  | Tmod_ident (path, _) ->
      push acc.modules (elt_of_path ~filename path mexpr.mod_loc)
  | _ -> ());
  Tast_iterator.default_iterator.module_expr this mexpr

let iter_typed_type_declaration ~filename acc this
    (decl : Typedtree.type_declaration) =
  let elt = elt_of_ident ~filename decl.typ_id decl.typ_name.loc in
  add_definition acc.types acc.type_definitions elt;
  (match decl.typ_kind with
  | Ttype_variant constructors ->
      List.iter
        (fun (cd : Typedtree.constructor_declaration) ->
          let elt = elt_of_ident ~filename cd.cd_id cd.cd_name.loc in
          add_definition acc.variants acc.variant_definitions elt)
        constructors
  | _ -> ());
  Tast_iterator.default_iterator.type_declaration this decl

let iter_typed_type_extension ~filename acc this
    (ext : Typedtree.type_extension) =
  List.iter
    (fun (ec : Typedtree.extension_constructor) ->
      let elt = elt_of_ident ~filename ec.ext_id ec.ext_name.loc in
      add_definition acc.variants acc.variant_definitions elt)
    ext.tyext_constructors;
  Tast_iterator.default_iterator.type_extension this ext

let iter_typed_type_exception ~filename acc this
    (exn : Typedtree.type_exception) =
  let ec = exn.tyexn_constructor in
  push acc.exceptions (elt_of_ident ~filename ec.ext_id ec.ext_name.loc);
  Tast_iterator.default_iterator.type_exception this exn

let iter_typed_value_binding ~filename acc this (vb : Typedtree.value_binding) =
  List.iter (push acc.values) (pattern_value_names ~filename vb.vb_pat);
  Tast_iterator.default_iterator.value_binding this vb

let collect_resolved ~filename (tree : Merlin.typedtree) =
  let acc = refs_acc () in
  let iterator =
    {
      Tast_iterator.default_iterator with
      expr = iter_typed_expr ~filename acc;
      pat =
        (fun (type k) this (pat : k Typedtree.general_pattern) ->
          iter_typed_pat ~filename acc this pat);
      typ = iter_typed_typ ~filename acc;
      module_expr = iter_typed_module_expr ~filename acc;
      module_binding =
        (fun this mb ->
          add_typed_module_ident ~filename acc mb.mb_id mb.mb_name.loc;
          Tast_iterator.default_iterator.module_binding this mb);
      module_declaration =
        (fun this md ->
          add_typed_module_ident ~filename acc md.md_id md.md_name.loc;
          Tast_iterator.default_iterator.module_declaration this md);
      type_declaration = iter_typed_type_declaration ~filename acc;
      type_extension = iter_typed_type_extension ~filename acc;
      type_exception = iter_typed_type_exception ~filename acc;
      value_binding = iter_typed_value_binding ~filename acc;
      value_description =
        (fun this vd ->
          add_value_sig ~filename acc vd;
          Tast_iterator.default_iterator.value_description this vd);
    }
  in
  (match tree with
  | `Implementation structure -> iterator.structure iterator structure
  | `Interface signature -> iterator.signature iterator signature);
  collected_refs_of_acc acc

type t = {
  filename : string;
  content : string Lazy.t;
  typedtree : Merlin.typedtree option Lazy.t;
  parsetree : Parsetree.structure option Lazy.t;
  signature_ : Parsetree.signature option Lazy.t;
  functions : (string * Ast.expr) list Lazy.t;
  ast : Ast.t Lazy.t;
  reference_outline : collected_refs Lazy.t;
  resolved : collected_refs option Lazy.t;
  outline : Outline.t Lazy.t;
}

let lazy_content ~filename ~load_content =
  lazy
    (try load_content ()
     with exn ->
       fail "Failed to read file %s: %s" filename (Printexc.to_string exn))

let lazy_typedtree typedtree =
  lazy
    (match typedtree with
    | Some f -> ( match f () with Ok t -> t | Error msg -> fail "%s" msg)
    | None -> None)

let lazy_parsetree ~filename ~typedtree ~parsetree ~content =
  lazy
    (let loaded_typedtree =
       if Lazy.is_val typedtree then
         try Lazy.force typedtree with Analysis_error _ -> None
       else None
     in
     match loaded_typedtree with
     | Some (`Implementation structure) ->
         Some (Ocaml_typing.Untypeast.untype_structure structure)
     | _ -> (
         match parsetree with
         | Some f -> ( match f () with Ok p -> p | Error msg -> fail "%s" msg)
         | None ->
             let content = Lazy.force content in
             Ast.parse_structure ~filename content))

let lazy_signature ~typedtree ~signature =
  lazy
    (let loaded_typedtree =
       if Lazy.is_val typedtree then
         try Lazy.force typedtree with Analysis_error _ -> None
       else None
     in
     match loaded_typedtree with
     | Some (`Interface signature) ->
         Some (Ocaml_typing.Untypeast.untype_signature signature)
     | Some (`Implementation _) | None -> (
         match signature with
         | Some f -> ( match f () with Ok s -> s | Error msg -> fail "%s" msg)
         | None -> None))

let lazy_functions parsetree =
  lazy
    (match Lazy.force parsetree with
    | None -> []
    | Some structure ->
        let fns = Ast.functions_of_structure structure in
        Log.debug (fun m -> m "File_view: %d functions" (List.length fns));
        fns)

let lazy_reference_outline ~filename ~typedtree ~parsetree =
  lazy
    (match Lazy.force typedtree with
    | Some tree -> collect_resolved ~filename tree
    | None -> (
        match Lazy.force parsetree with
        | None -> empty_refs
        | Some structure -> collect_parsetree_outline ~filename structure))

let lazy_outline outline =
  lazy (match outline () with Ok o -> o | Error msg -> fail "%s" msg)

let lazy_resolved ~filename ~typedtree =
  lazy
    (match Lazy.force typedtree with
    | None -> None
    | Some tree -> Some (collect_resolved ~filename tree))

let v ~filename ~load_content ?typedtree ?parsetree ?signature ~outline () =
  let content = lazy_content ~filename ~load_content in
  let typedtree = lazy_typedtree typedtree in
  let parsetree = lazy_parsetree ~filename ~typedtree ~parsetree ~content in
  let signature_ = lazy_signature ~typedtree ~signature in
  let functions = lazy_functions parsetree in
  let ast = lazy { Ast.functions = Lazy.force functions } in
  let reference_outline =
    lazy_reference_outline ~filename ~typedtree ~parsetree
  in
  let outline = lazy_outline outline in
  let resolved = lazy_resolved ~filename ~typedtree in
  {
    filename;
    content;
    typedtree;
    parsetree;
    signature_;
    functions;
    ast;
    reference_outline;
    resolved;
    outline;
  }

let filename t = t.filename
let content t = Lazy.force t.content
let typedtree t = Lazy.force t.typedtree
let parsetree t = Lazy.force t.parsetree
let signature t = Lazy.force t.signature_
let functions t = Lazy.force t.functions
let ast t = Lazy.force t.ast
let outline t = Lazy.force t.outline
let is_resolved t = Option.is_some (Lazy.force t.typedtree)

(* {2 Name} *)

module Name = struct
  type t = Merlin.Refs.name

  let to_string = Merlin.Refs.string_of_name
  let base (n : t) = n.base
  let prefix (n : t) = n.prefix

  let equals_path (n : t) path =
    let rec walk pre rem =
      match (pre, rem) with
      | [], [ b ] -> b = n.base
      | p :: ps, r :: rs when p = r -> walk ps rs
      | _ -> false
    in
    walk n.prefix path

  let pp ppf t = Fmt.string ppf (to_string t)
end

(* {2 Type_view} *)

module Type_view = struct
  type t = Compiler_parsetree.core_type

  let is_function (ct : t) =
    match ct.ptyp_desc with Ptyp_arrow _ -> true | _ -> false

  let rec return_type (ct : t) : t option =
    match ct.ptyp_desc with
    | Ptyp_arrow (_, _, ret) -> return_type ret
    | _ -> Some ct

  let rec returns_option (ct : t) =
    match ct.ptyp_desc with
    | Ptyp_arrow (_, _, ret) -> returns_option ret
    | Ptyp_constr ({ txt = Lident "option"; _ }, _) -> true
    | _ -> false

  let count_unlabelled (ct : t) ~match_ =
    let rec aux acc (ct : t) =
      match ct.ptyp_desc with
      | Ptyp_arrow (Nolabel, dom, rest) ->
          let acc = if match_ dom then acc + 1 else acc in
          aux acc rest
      | Ptyp_arrow (_, _, rest) -> aux acc rest
      | _ -> acc
    in
    aux 0 ct

  let pp ppf ct =
    Compiler_pprintast.core_type Format.str_formatter ct;
    Fmt.string ppf (Format.flush_str_formatter ())
end

(* {2 Item} *)

module Item = struct
  type kind =
    | Value
    | Type
    | Module
    | Module_type
    | Class
    | Class_type
    | Constructor
    | Exception
    | Field
    | Method
    | Label

  type t = { item : Outline.item; filename : string }

  let kind_of_outline : Outline.kind -> kind = function
    | Value -> Value
    | Type -> Type
    | Module -> Module
    | Module_type -> Module_type
    | Class -> Class
    | Class_type -> Class_type
    | Constructor -> Constructor
    | Exception -> Exception
    | Field -> Field
    | Method -> Method
    | Label -> Label

  let name (t : t) = t.item.name
  let kind (t : t) = kind_of_outline t.item.kind
  let deprecated (t : t) = t.item.deprecated

  let loc (t : t) =
    let loc = t.item.location in
    Merlin.Location.v ~file:t.filename ~start_line:loc.start.line
      ~start_col:loc.start.col ~end_line:loc.end_.line ~end_col:loc.end_.col

  let type_sig (t : t) = Outline.parsed_type t.item

  let children (t : t) =
    List.map (fun item -> { item; filename = t.filename }) t.item.children
end

(* {2 Reference} *)

module Reference = struct
  type t = Merlin.Refs.elt

  let name (e : t) = e.name
  let loc (e : t) = e.location
  let base e = Name.base (name e)
  let prefix e = Name.prefix (name e)
  let matches_path e path = Name.equals_path (name e) path
end

(* {2 Value_sig} *)

module Value_sig = struct
  type t = Merlin.Refs.value_sig

  let name (v : t) = v.name
  let loc (v : t) = v.location
  let type_path (v : t) = v.type_path
end

(* {2 Call} *)

module Call = struct
  type arg = { arg_expr : Parsetree.expression; arg_filename : string }

  type t = {
    callee : Merlin.Refs.name;
    args : arg list;
    loc : Merlin.Location.t;
  }

  let callee t = t.callee
  let args t = t.args
  let loc t = t.loc

  let name_of_lident (lid : Longident.t) : Merlin.Refs.name =
    let rec parts acc : Longident.t -> string list = function
      | Lident s -> s :: acc
      | Ldot (l, s) -> parts (s.txt :: acc) l.txt
      | Lapply _ -> acc
    in
    match parts [] lid with
    | [] -> { prefix = []; base = "" }
    | xs ->
        let rev = List.rev xs in
        { prefix = List.rev (List.tl rev); base = List.hd rev }

  module Arg = struct
    let loc a = Ast.merlint_of_loc ~filename:a.arg_filename a.arg_expr.pexp_loc
    let is_call a ~path = Ast.is_apply_of path a.arg_expr
  end
end

(* {2 Top-level accessors over Outline / Dump} *)

let items t =
  List.map (fun item -> { Item.item; filename = t.filename }) (outline t)

let outline_refs t = (Lazy.force t.reference_outline).refs
let outline_identifiers t = (outline_refs t).identifiers
let outline_patterns t = (outline_refs t).patterns
let outline_variants t = (outline_refs t).variants

let outline_variant_definitions t =
  (Lazy.force t.reference_outline).variant_definitions

let outline_modules t = (outline_refs t).modules

let outline_module_definitions t =
  (Lazy.force t.reference_outline).module_definitions

let outline_types t = (outline_refs t).types

let outline_type_definitions t =
  (Lazy.force t.reference_outline).type_definitions

let outline_exceptions t = (outline_refs t).exceptions
let outline_values t = (outline_refs t).values

let resolved_identifiers t =
  Option.map (fun d -> d.refs.Merlin.Refs.identifiers) (Lazy.force t.resolved)

let resolved_patterns t =
  Option.map (fun d -> d.refs.Merlin.Refs.patterns) (Lazy.force t.resolved)

let resolved_variants t =
  Option.map (fun d -> d.refs.Merlin.Refs.variants) (Lazy.force t.resolved)

let resolved_modules t =
  Option.map (fun d -> d.refs.Merlin.Refs.modules) (Lazy.force t.resolved)

let resolved_types t =
  Option.map (fun d -> d.refs.Merlin.Refs.types) (Lazy.force t.resolved)

let resolved_exceptions t =
  Option.map (fun d -> d.refs.Merlin.Refs.exceptions) (Lazy.force t.resolved)

let resolved_values t =
  Option.map (fun d -> d.refs.Merlin.Refs.values) (Lazy.force t.resolved)

let resolved_signatures t =
  Option.map (fun d -> d.refs.Merlin.Refs.value_sigs) (Lazy.force t.resolved)

let iter_applications t f =
  match parsetree t with
  | None -> ()
  | Some structure ->
      Ast.iter_apply structure (fun expr fn args ->
          let loc = Ast.merlint_of_loc ~filename:t.filename expr.pexp_loc in
          let args =
            List.map
              (fun (_lbl, e) ->
                { Call.arg_expr = e; arg_filename = t.filename })
              args
          in
          let call = { Call.callee = Call.name_of_lident fn; args; loc } in
          f call)
