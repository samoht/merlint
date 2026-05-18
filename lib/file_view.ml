let src = Logs.Src.create "merlint.file_view" ~doc:"File view"

module Log = (val Logs.src_log src : Logs.LOG)
module Typedtree = Ocaml_typing.Typedtree
module Tast_iterator = Ocaml_typing.Tast_iterator
module Typed_ident = Ocaml_typing.Ident
module Typed_path = Ocaml_typing.Path
module Typed_predef = Ocaml_typing.Predef
module Typed_types = Ocaml_typing.Types
open Ocaml_parsing

exception Analysis_error of string

let fail fmt = Fmt.kstr (fun s -> raise (Analysis_error s)) fmt

let clean_name_part s =
  match String.index_opt s '!' with None -> s | Some i -> String.sub s 0 i

let name_of_parts parts =
  match List.map clean_name_part parts with
  | [] -> { Merlin.Refs.prefix = []; base = "" }
  | parts ->
      let rev = List.rev parts in
      { Merlin.Refs.prefix = List.rev (List.tl rev); base = List.hd rev }

let name_of_string_path path =
  path |> String.split_on_char '.'
  |> List.filter (fun s -> s <> "")
  |> name_of_parts

let predef_path_name path =
  [
    (Typed_predef.path_int, "int");
    (Typed_predef.path_char, "char");
    (Typed_predef.path_string, "string");
    (Typed_predef.path_bytes, "bytes");
    (Typed_predef.path_float, "float");
    (Typed_predef.path_bool, "bool");
    (Typed_predef.path_unit, "unit");
    (Typed_predef.path_list, "list");
    (Typed_predef.path_int32, "int32");
    (Typed_predef.path_int64, "int64");
  ]
  |> List.find_map (fun (predef, name) ->
         if Typed_path.same path predef then Some name else None)

let name_of_path path =
  match predef_path_name path with
  | Some name -> name_of_parts [ name ]
  | None -> (
      match Typed_path.flatten path with
      | `Ok (base, suffix) ->
          let name = name_of_parts (Typed_ident.name base :: suffix) in
          if name.Merlin.Refs.base = "" then
            name_of_string_path (Typed_path.name path)
          else name
      | `Contains_apply -> name_of_string_path (Typed_path.name path))

let name_of_ident ident = name_of_parts [ Typed_ident.name ident ]

let name_of_longident lid =
  let rec parts acc = function
    | Longident.Lident s -> s :: acc
    | Ldot (prefix, s) -> parts (s.txt :: acc) prefix.txt
    | Lapply _ -> acc
  in
  name_of_parts (parts [] lid)

let loc_of_typed_loc ~filename loc =
  if loc.Location.loc_ghost then None else Some (Loc.of_typed ~filename loc)

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

let add_definition target definitions elt =
  push target elt;
  push definitions elt

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

type item_kind =
  | Item_value
  | Item_type
  | Item_module
  | Item_module_type
  | Item_class
  | Item_class_type
  | Item_constructor
  | Item_exception
  | Item_field

type file_item = {
  item_name : string;
  item_kind : item_kind;
  item_loc : Location.t;
  item_deprecated : bool;
  item_type : Typed_types.type_expr option;
  item_children : file_item list;
}

type application_arg = {
  arg_callee : Merlin.Refs.name option;
  arg_loc : Location.t;
}

type application_site = {
  call_callee : Merlin.Refs.name;
  call_loc : Location.t;
  call_args : application_arg list;
}

type t = {
  filename : string;
  typedtree : Merlin.typedtree option Lazy.t;
  values : Function_metrics.value list Lazy.t;
  reference_outline : collected_refs Lazy.t;
  items : file_item list Lazy.t;
  resolved : collected_refs option Lazy.t;
  module_names : string list Lazy.t;
  applications : application_site list Lazy.t;
      (** Cache of every typed application site whose head is a path identifier.
          One typedtree walk per file regardless of how many rules call
          {!iter_applications}. *)
}

let warn_missing_typedtree filename =
  Log.warn (fun m ->
      m
        "No fresh typedtree found for %s; typedtree-backed rules are skipped \
         for this file. Run dune build @check before merlint so the .cmt/.cmti \
         artefact exists and is up to date."
        filename)

let lazy_typedtree ~filename typedtree =
  lazy
    (match typedtree () with
    | Ok (Some _ as tree) -> tree
    | Ok None ->
        warn_missing_typedtree filename;
        None
    | Error msg ->
        Log.warn (fun m ->
            m
              "Failed to load typedtree for %s: %s; typedtree-backed rules are \
               skipped for this file. Run dune build @check before merlint so \
               the .cmt/.cmti artefact exists and is up to date."
              filename msg);
        fail "%s" msg)

let lazy_reference_outline ~filename ~typedtree =
  lazy
    (match Lazy.force typedtree with
    | Some tree -> collect_resolved ~filename tree
    | None -> empty_refs)

let lazy_resolved ~filename ~typedtree =
  lazy
    (match Lazy.force typedtree with
    | None -> None
    | Some tree -> Some (collect_resolved ~filename tree))

let typed_has_deprecated attrs =
  List.exists
    (fun (attr : Parsetree.attribute) ->
      attr.attr_name.txt = "deprecated"
      || attr.attr_name.txt = "ocaml.deprecated")
    attrs

let typed_item ~name ~kind ?item_type ?(children = []) ?(deprecated = false) loc
    =
  {
    item_name = name;
    item_kind = kind;
    item_loc = loc;
    item_deprecated = deprecated;
    item_type;
    item_children = children;
  }

let rec typed_pattern_items ?loc (pat : Typedtree.pattern) =
  let item_loc = Option.value loc ~default:pat.pat_loc in
  match pat.pat_desc with
  | Tpat_var (_ident, name, _) ->
      [
        typed_item ~name:name.txt ~kind:Item_value ~item_type:pat.pat_type
          item_loc;
      ]
  | Tpat_alias (p, _ident, name, _, _) ->
      typed_item ~name:name.txt ~kind:Item_value ~item_type:pat.pat_type
        item_loc
      :: typed_pattern_items ?loc p
  | Tpat_tuple fields ->
      List.concat_map (fun (_, p) -> typed_pattern_items ?loc p) fields
  | Tpat_construct (_, _, args, _) ->
      List.concat_map (typed_pattern_items ?loc) args
  | Tpat_variant (_, arg, _) -> (
      match arg with None -> [] | Some p -> typed_pattern_items ?loc p)
  | Tpat_record (fields, _) ->
      List.concat_map (fun (_, _, p) -> typed_pattern_items ?loc p) fields
  | Tpat_array (_, pats) -> List.concat_map (typed_pattern_items ?loc) pats
  | Tpat_or (lhs, rhs, _) ->
      typed_pattern_items ?loc lhs @ typed_pattern_items ?loc rhs
  | Tpat_lazy p -> typed_pattern_items ?loc p
  | Tpat_any | Tpat_constant _ -> []

let typed_type_children (decl : Typedtree.type_declaration) =
  match decl.typ_kind with
  | Ttype_record labels ->
      List.map
        (fun (ld : Typedtree.label_declaration) ->
          typed_item ~name:ld.ld_name.txt ~kind:Item_field
            ~item_type:ld.ld_type.ctyp_type
            ~deprecated:(typed_has_deprecated ld.ld_attributes)
            ld.ld_loc)
        labels
  | Ttype_variant constructors ->
      List.map
        (fun (cd : Typedtree.constructor_declaration) ->
          typed_item ~name:cd.cd_name.txt ~kind:Item_constructor
            ~deprecated:(typed_has_deprecated cd.cd_attributes)
            cd.cd_loc)
        constructors
  | Ttype_abstract | Ttype_open -> []

let typed_type_item (decl : Typedtree.type_declaration) =
  typed_item ~name:decl.typ_name.txt ~kind:Item_type
    ?item_type:
      (Option.map
         (fun (ct : Typedtree.core_type) -> ct.ctyp_type)
         decl.typ_manifest)
    ~children:(typed_type_children decl)
    ~deprecated:(typed_has_deprecated decl.typ_attributes)
    decl.typ_loc

let typed_extension_item (ext : Typedtree.extension_constructor) =
  typed_item ~name:ext.ext_name.txt ~kind:Item_constructor
    ~deprecated:(typed_has_deprecated ext.ext_attributes)
    ext.ext_loc

let typed_exception_item (exn : Typedtree.type_exception) =
  let ext = exn.tyexn_constructor in
  typed_item ~name:ext.ext_name.txt ~kind:Item_exception
    ~deprecated:(typed_has_deprecated ext.ext_attributes)
    ext.ext_loc

let rec typed_structure_items (structure : Typedtree.structure) =
  List.concat_map typed_structure_item structure.str_items

and typed_structure_item (item : Typedtree.structure_item) =
  match item.str_desc with
  | Tstr_value (_, bindings) ->
      List.concat_map
        (fun (vb : Typedtree.value_binding) ->
          typed_pattern_items ~loc:vb.vb_loc vb.vb_pat)
        bindings
  | Tstr_primitive vd ->
      [
        typed_item ~name:vd.val_name.txt ~kind:Item_value
          ~item_type:vd.val_desc.ctyp_type
          ~deprecated:(typed_has_deprecated vd.val_attributes)
          vd.val_loc;
      ]
  | Tstr_type (_, decls) -> List.map typed_type_item decls
  | Tstr_module mb ->
      Option.fold mb.mb_name.txt ~none:[] ~some:(fun name ->
          let children =
            match mb.mb_expr.mod_desc with
            | Tmod_structure s -> typed_structure_items s
            | _ -> []
          in
          [
            typed_item ~name ~kind:Item_module ~children
              ~deprecated:(typed_has_deprecated mb.mb_attributes)
              mb.mb_loc;
          ])
  | Tstr_recmodule mods ->
      List.filter_map
        (fun (mb : Typedtree.module_binding) ->
          Option.map
            (fun name ->
              let children =
                match mb.mb_expr.mod_desc with
                | Tmod_structure s -> typed_structure_items s
                | _ -> []
              in
              typed_item ~name ~kind:Item_module ~children
                ~deprecated:(typed_has_deprecated mb.mb_attributes)
                mb.mb_loc)
            mb.mb_name.txt)
        mods
  | Tstr_modtype mtd ->
      [
        typed_item ~name:mtd.mtd_name.txt ~kind:Item_module_type
          ~children:
            (match mtd.mtd_type with
            | Some { mty_desc = Tmty_signature s; _ } -> typed_signature_items s
            | _ -> [])
          ~deprecated:(typed_has_deprecated mtd.mtd_attributes)
          mtd.mtd_loc;
      ]
  | Tstr_exception exn -> [ typed_exception_item exn ]
  | Tstr_typext te -> List.map typed_extension_item te.tyext_constructors
  | Tstr_class classes ->
      List.map
        (fun ((cd, _) : Typedtree.class_declaration * string list) ->
          typed_item ~name:cd.ci_id_name.txt ~kind:Item_class cd.ci_loc)
        classes
  | Tstr_class_type classes ->
      List.map
        (fun ((_, name, cd) :
               Typed_ident.t
               * string Ocaml_parsing.Asttypes.loc
               * Typedtree.class_type_declaration) ->
          typed_item ~name:name.txt ~kind:Item_class_type cd.ci_loc)
        classes
  | Tstr_eval _ | Tstr_open _ | Tstr_include _ | Tstr_attribute _ -> []

and typed_signature_items (signature : Typedtree.signature) =
  List.concat_map typed_signature_item signature.sig_items

and typed_signature_item (item : Typedtree.signature_item) =
  match item.sig_desc with
  | Tsig_value vd ->
      [
        typed_item ~name:vd.val_name.txt ~kind:Item_value
          ~item_type:vd.val_desc.ctyp_type
          ~deprecated:(typed_has_deprecated vd.val_attributes)
          vd.val_loc;
      ]
  | Tsig_type (_, decls) | Tsig_typesubst decls ->
      List.map typed_type_item decls
  | Tsig_module md ->
      Option.fold md.md_name.txt ~none:[] ~some:(fun name ->
          [
            typed_item ~name ~kind:Item_module
              ~children:
                (match md.md_type.mty_desc with
                | Tmty_signature s -> typed_signature_items s
                | _ -> [])
              ~deprecated:(typed_has_deprecated md.md_attributes)
              md.md_loc;
          ])
  | Tsig_recmodule mods ->
      List.filter_map
        (fun (md : Typedtree.module_declaration) ->
          Option.map
            (fun name ->
              typed_item ~name ~kind:Item_module
                ~children:
                  (match md.md_type.mty_desc with
                  | Tmty_signature s -> typed_signature_items s
                  | _ -> [])
                ~deprecated:(typed_has_deprecated md.md_attributes)
                md.md_loc)
            md.md_name.txt)
        mods
  | Tsig_modtype mtd ->
      [
        typed_item ~name:mtd.mtd_name.txt ~kind:Item_module_type
          ~children:
            (match mtd.mtd_type with
            | Some { mty_desc = Tmty_signature s; _ } -> typed_signature_items s
            | _ -> [])
          ~deprecated:(typed_has_deprecated mtd.mtd_attributes)
          mtd.mtd_loc;
      ]
  | Tsig_exception exn -> [ typed_exception_item exn ]
  | Tsig_typext te -> List.map typed_extension_item te.tyext_constructors
  | Tsig_class classes ->
      List.map
        (fun (cd : Typedtree.class_description) ->
          typed_item ~name:cd.ci_id_name.txt ~kind:Item_class cd.ci_loc)
        classes
  | Tsig_class_type classes ->
      List.map
        (fun (cd : Typedtree.class_type_declaration) ->
          typed_item ~name:cd.ci_id_name.txt ~kind:Item_class_type cd.ci_loc)
        classes
  | Tsig_open _ | Tsig_include _ | Tsig_attribute _ | Tsig_modsubst _
  | Tsig_modtypesubst _ ->
      []

let lazy_items typedtree =
  lazy
    (match Lazy.force typedtree with
    | Some (`Implementation structure) -> typed_structure_items structure
    | Some (`Interface signature) -> typed_signature_items signature
    | None -> [])

let lazy_values typedtree =
  lazy
    (match Lazy.force typedtree with
    | Some (`Implementation structure) ->
        Function_metrics.of_structure structure
    | Some (`Interface _) | None -> [])

let typed_expr_callee_name (expr : Typedtree.expression) =
  let rec aux (expr : Typedtree.expression) =
    match expr.exp_desc with
    | Texp_ident (path, _, _) -> Some (name_of_path path)
    | Texp_apply (fn, _) -> aux fn
    | Texp_construct (lid, _, _) -> Some (name_of_longident lid.txt)
    | Texp_open (_, body) -> aux body
    | _ -> None
  in
  aux expr

let application_args args =
  List.filter_map
    (function
      | _, Typedtree.Omitted _ -> None
      | _, Typedtree.Arg (expr : Typedtree.expression) ->
          Some
            { arg_callee = typed_expr_callee_name expr; arg_loc = expr.exp_loc })
    args

let push_application calls expr fn args =
  Option.iter
    (fun call_callee ->
      push calls
        {
          call_callee;
          call_loc = expr.Typedtree.exp_loc;
          call_args = application_args args;
        })
    (typed_expr_callee_name fn)

let lazy_applications typedtree =
  lazy
    (match Lazy.force typedtree with
    | None | Some (`Interface _) -> []
    | Some (`Implementation structure) ->
        let calls = ref [] in
        let iterator =
          {
            Tast_iterator.default_iterator with
            expr =
              (fun this expr ->
                (match expr.exp_desc with
                | Texp_apply (fn, args) -> push_application calls expr fn args
                | _ -> ());
                Tast_iterator.default_iterator.expr this expr);
          }
        in
        iterator.structure iterator structure;
        List.rev !calls)

let is_module_name name =
  String.length name > 0
  && Char.uppercase_ascii name.[0] = name.[0]
  && Char.lowercase_ascii name.[0] <> name.[0]

let add_module_name acc name = if is_module_name name then name :: acc else acc

let module_names_of_name (name : Merlin.Refs.name) acc =
  List.fold_left add_module_name (add_module_name acc name.base) name.prefix

let module_names_of_ref acc (elt : Merlin.Refs.elt) =
  module_names_of_name elt.name acc

let lazy_module_names refs =
  lazy
    (let refs = (Lazy.force refs).refs in
     let names = [] in
     let names = List.fold_left module_names_of_ref names refs.modules in
     let names = List.fold_left module_names_of_ref names refs.types in
     let names = List.fold_left module_names_of_ref names refs.exceptions in
     let names = List.fold_left module_names_of_ref names refs.variants in
     let names = List.fold_left module_names_of_ref names refs.identifiers in
     let names = List.fold_left module_names_of_ref names refs.patterns in
     let names = List.fold_left module_names_of_ref names refs.values in
     List.sort_uniq String.compare names)

let v ~filename ~typedtree () =
  let typedtree = lazy_typedtree ~filename typedtree in
  let values = lazy_values typedtree in
  let reference_outline = lazy_reference_outline ~filename ~typedtree in
  let items = lazy_items typedtree in
  let resolved = lazy_resolved ~filename ~typedtree in
  let module_names = lazy_module_names reference_outline in
  let applications = lazy_applications typedtree in
  {
    filename;
    typedtree;
    values;
    reference_outline;
    items;
    resolved;
    module_names;
    applications;
  }

let filename t = t.filename
let typedtree t = Lazy.force t.typedtree
let values t = Lazy.force t.values
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
  type t = Typed_types.type_expr

  let arrow ct =
    match Typed_types.get_desc ct with
    | Typed_types.Tarrow (label, dom, ret, _) -> Some (label, dom, ret)
    | _ -> None

  let is_function (ct : t) = Option.is_some (arrow ct)

  let is_variable ct =
    match Typed_types.get_desc ct with
    | Typed_types.Tvar _ | Typed_types.Tunivar _ -> true
    | _ -> false

  let tuple ct =
    match Typed_types.get_desc ct with
    | Typed_types.Ttuple fields -> Some (List.map snd fields)
    | _ -> None

  let constr ct =
    match Typed_types.get_desc ct with
    | Typed_types.Tconstr (path, args, _) -> Some (name_of_path path, args)
    | _ -> None

  let constr_path ct =
    match Typed_types.get_desc ct with
    | Typed_types.Tconstr (path, _, _) -> Some path
    | _ -> None

  let rec constrs ct =
    match Typed_types.get_desc ct with
    | Typed_types.Tconstr (path, args, _) ->
        name_of_path path :: List.concat_map constrs args
    | Typed_types.Ttuple fields ->
        List.concat_map (fun (_, t) -> constrs t) fields
    | Typed_types.Tarrow (_, dom, ret, _) -> constrs dom @ constrs ret
    | Typed_types.Tpoly (body, args) ->
        constrs body @ List.concat_map constrs args
    | Typed_types.Tvariant row -> (
        match Typed_types.row_name row with
        | Some (path, args) -> name_of_path path :: List.concat_map constrs args
        | None -> [])
    | _ -> []

  let is_constr ct ~path =
    match constr ct with
    | Some (name, _) -> Name.equals_path name path
    | None -> false

  let is_predef ct path =
    match constr_path ct with
    | Some actual -> Typed_path.same actual path
    | None -> false

  let is_unit ct =
    is_predef ct Typed_predef.path_unit
    || is_constr ct ~path:[ "Stdlib"; "unit" ]

  let is_bool ct =
    is_predef ct Typed_predef.path_bool
    || is_constr ct ~path:[ "Stdlib"; "bool" ]

  let is_string ct =
    is_predef ct Typed_predef.path_string
    || is_constr ct ~path:[ "Stdlib"; "string" ]

  let is_list ct ~elem =
    match (constr_path ct, constr ct) with
    | Some path, Some (_, [ arg ])
      when Typed_path.same path Typed_predef.path_list ->
        elem arg
    | _, Some (name, [ arg ]) ->
        Name.equals_path name [ "Stdlib"; "list" ] && elem arg
    | _ -> false

  let rec return_type (ct : t) : t option =
    match Typed_types.get_desc ct with
    | Typed_types.Tarrow (_, _, ret, _) -> return_type ret
    | _ -> Some ct

  let rec returns_option (ct : t) =
    match Typed_types.get_desc ct with
    | Typed_types.Tarrow (_, _, ret, _) -> returns_option ret
    | Typed_types.Tconstr (path, _, _) ->
        Typed_path.same path Typed_predef.path_option
        || name_of_path path |> fun n ->
           Name.equals_path n [ "Stdlib"; "option" ]
    | _ -> false

  let count_unlabelled (ct : t) ~match_ =
    let rec aux acc (ct : t) =
      match Typed_types.get_desc ct with
      | Typed_types.Tarrow (Asttypes.Nolabel, dom, rest, _) ->
          let acc = if match_ dom then acc + 1 else acc in
          aux acc rest
      | Typed_types.Tarrow (_, _, rest, _) -> aux acc rest
      | _ -> acc
    in
    aux 0 ct

  let pp ppf (ct : t) =
    Ocaml_typing.Printtyp.type_expr Format.str_formatter ct;
    match Format.flush_str_formatter () with
    | "" -> (
        match constr ct with
        | Some (name, []) -> Name.pp ppf name
        | _ -> ())
    | s -> Fmt.string ppf s
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

  type t = { item : file_item; filename : string }

  let kind_of_item = function
    | Item_value -> Value
    | Item_type -> Type
    | Item_module -> Module
    | Item_module_type -> Module_type
    | Item_class -> Class
    | Item_class_type -> Class_type
    | Item_constructor -> Constructor
    | Item_exception -> Exception
    | Item_field -> Field

  let name (t : t) = t.item.item_name
  let kind (t : t) = kind_of_item t.item.item_kind
  let deprecated (t : t) = t.item.item_deprecated
  let loc (t : t) = Loc.of_typed ~filename:t.filename t.item.item_loc
  let type_sig (t : t) = t.item.item_type

  let children (t : t) =
    List.map (fun item -> { item; filename = t.filename }) t.item.item_children
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
  type arg = {
    arg_callee : Merlin.Refs.name option;
    arg_loc : Location.t;
    arg_filename : string;
  }

  type t = {
    callee : Merlin.Refs.name;
    args : arg list;
    loc : Merlin.Location.t;
  }

  let callee t = t.callee
  let args t = t.args
  let loc t = t.loc

  module Arg = struct
    let loc a = Loc.of_typed ~filename:a.arg_filename a.arg_loc

    let is_call a ~path =
      match a.arg_callee with
      | None -> false
      | Some name -> Name.equals_path name path
  end
end

(* {2 Top-level accessors} *)

let items t =
  List.map
    (fun item -> { Item.item; filename = t.filename })
    (Lazy.force t.items)

let rec flatten_items items =
  List.concat_map (fun item -> item :: flatten_items (Item.children item)) items

let all_items t = flatten_items (items t)

let value_items t =
  List.filter (fun item -> Item.kind item = Item.Value) (all_items t)

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

let referenced_module_names t = Lazy.force t.module_names

let iter_applications t f =
  Lazy.force t.applications
  |> List.iter (fun { call_callee; call_loc; call_args } ->
      let loc = Loc.of_typed ~filename:t.filename call_loc in
      let args =
        List.map
          (fun { arg_callee; arg_loc } ->
            { Call.arg_callee; arg_loc; arg_filename = t.filename })
          call_args
      in
      let call = { Call.callee = call_callee; args; loc } in
      f call)

let calls_path t path =
  let found = ref false in
  iter_applications t (fun call ->
      if Name.equals_path (Call.callee call) path then found := true);
  !found

let references_path t path =
  match resolved_identifiers t with
  | None -> false
  | Some refs -> List.exists (fun r -> Reference.matches_path r path) refs

let ends_with ~suffix path =
  let rec drop n xs =
    if n <= 0 then xs else match xs with [] -> [] | _ :: xs -> drop (n - 1) xs
  in
  let len = List.length path in
  let suffix_len = List.length suffix in
  len >= suffix_len && drop (len - suffix_len) path = suffix

let references_suffix t suffix =
  match resolved_identifiers t with
  | None -> false
  | Some refs ->
      List.exists
        (fun r ->
          let name = Reference.name r in
          ends_with ~suffix (Name.prefix name @ [ Name.base name ]))
        refs
