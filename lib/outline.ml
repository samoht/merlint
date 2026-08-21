(* Bare [Parsetree], [Asttypes], [Warnings] and [Longident] here are
   compiler-libs': the tree walked is the one {!Ast} parsed with the stock
   parser, so that a declaration's span is the very span [Doc_comments] keyed
   its doc comment by. What leaves the module is in merlint's ambient types --
   merlin's [Ocaml_parsing] -- because that is what a location and an argument
   label are everywhere else here; the two conversions below are that
   boundary. *)

type kind =
  | Value
  | Type
  | Module
  | Module_type
  | Class
  | Class_type
  | Constructor
  | Exception
  | Extension
  | Field
  | Method
  | Instance_variable

type item = {
  name : string;
  kind : kind;
  loc : Ocaml_parsing.Location.t;
  deprecated : bool;
  deriving : string list;
  arg_labels : Ocaml_parsing.Asttypes.arg_label list;
  mutable_field : bool;
  children : item list;
}

let loc_of (loc : Warnings.loc) : Ocaml_parsing.Location.t =
  {
    loc_start = loc.loc_start;
    loc_end = loc.loc_end;
    loc_ghost = loc.loc_ghost;
  }

let arg_label_of : Asttypes.arg_label -> Ocaml_parsing.Asttypes.arg_label =
  function
  | Nolabel -> Nolabel
  | Labelled name -> Labelled name
  | Optional name -> Optional name

let item ~name ~kind ?(children = []) ?(deriving = []) ?(deprecated = false)
    ?(arg_labels = []) ?(mutable_field = false) loc =
  {
    name;
    kind;
    loc = loc_of loc;
    deprecated;
    deriving;
    arg_labels;
    mutable_field;
    children;
  }

let has_deprecated attrs =
  List.exists
    (fun (attr : Parsetree.attribute) ->
      attr.attr_name.txt = "deprecated"
      || attr.attr_name.txt = "ocaml.deprecated")
    attrs

let rec deriving_names_expr expr =
  match expr.Parsetree.pexp_desc with
  | Pexp_ident { txt = Longident.Lident name; _ } -> [ name ]
  | Pexp_tuple fields ->
      List.concat_map (fun (_, expr) -> deriving_names_expr expr) fields
  | _ -> []

let deriving_names attrs =
  List.concat_map
    (fun (attr : Parsetree.attribute) ->
      match (attr.attr_name.txt, attr.attr_payload) with
      | "deriving", PStr [ { pstr_desc = Pstr_eval (expr, _); _ } ] ->
          deriving_names_expr expr
      | _ -> [])
    attrs

(* The labels of a written arrow, outermost first. An alias or an explicit
   polymorphic annotation wraps the arrow without changing what it takes, so
   both are looked through. *)
let rec arg_labels_of (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_arrow (label, _, rest) -> arg_label_of label :: arg_labels_of rest
  | Ptyp_alias (typ, _) | Ptyp_poly (_, typ) -> arg_labels_of typ
  | _ -> []

let arg_labels_of_opt = function None -> [] | Some typ -> arg_labels_of typ

let rec pattern_items ?loc (pat : Parsetree.pattern) =
  let loc = Option.value loc ~default:pat.ppat_loc in
  match pat.ppat_desc with
  | Ppat_var name -> [ item ~name:name.txt ~kind:Value loc ]
  | Ppat_alias (p, name) ->
      item ~name:name.txt ~kind:Value loc :: pattern_items ~loc p
  | Ppat_tuple (fields, _) ->
      List.concat_map (fun (_, p) -> pattern_items ~loc p) fields
  | Ppat_construct (_, arg) -> (
      match arg with None -> [] | Some (_, p) -> pattern_items ~loc p)
  | Ppat_variant (_, arg) -> (
      match arg with None -> [] | Some p -> pattern_items ~loc p)
  | Ppat_record (fields, _) ->
      List.concat_map (fun (_, p) -> pattern_items ~loc p) fields
  | Ppat_array pats -> List.concat_map (pattern_items ~loc) pats
  | Ppat_or (lhs, rhs) -> pattern_items ~loc lhs @ pattern_items ~loc rhs
  (* The typechecker erases a constraint, an [M.(...)] opening and an
     [exception] pattern, so the typedtree reaches the variable underneath them
     and this has to as well. *)
  | Ppat_lazy p | Ppat_constraint (p, _) | Ppat_open (_, p) | Ppat_exception p
    ->
      pattern_items ~loc p
  | Ppat_effect _ | Ppat_any | Ppat_constant _ | Ppat_interval _ | Ppat_type _
  | Ppat_unpack _ | Ppat_extension _ ->
      []

let field_item (ld : Parsetree.label_declaration) =
  item ~name:ld.pld_name.txt ~kind:Field
    ~arg_labels:(arg_labels_of ld.pld_type)
    ~deprecated:(has_deprecated ld.pld_attributes)
    ~mutable_field:
      (match ld.pld_mutable with Mutable -> true | Immutable -> false)
    ld.pld_loc

(* A constructor declared with an inline record owns those fields: they belong
   to it, not to the enclosing type, and no other declaration can reach them. *)
let constructor_children (cd : Parsetree.constructor_declaration) =
  match cd.pcd_args with
  | Pcstr_record labels -> List.map field_item labels
  | Pcstr_tuple _ -> []

let type_children (decl : Parsetree.type_declaration) =
  match decl.ptype_kind with
  | Ptype_record labels -> List.map field_item labels
  | Ptype_variant constructors ->
      List.map
        (fun (cd : Parsetree.constructor_declaration) ->
          item ~name:cd.pcd_name.txt ~kind:Constructor
            ~deprecated:(has_deprecated cd.pcd_attributes)
            ~children:(constructor_children cd) cd.pcd_loc)
        constructors
  | Ptype_abstract | Ptype_open -> []

let type_item (decl : Parsetree.type_declaration) =
  item ~name:decl.ptype_name.txt ~kind:Type
    ~arg_labels:(arg_labels_of_opt decl.ptype_manifest)
    ~deriving:(deriving_names decl.ptype_attributes)
    ~children:(type_children decl)
    ~deprecated:(has_deprecated decl.ptype_attributes)
    decl.ptype_loc

let extension_item (ext : Parsetree.extension_constructor) =
  item ~name:ext.pext_name.txt ~kind:Extension
    ~deprecated:(has_deprecated ext.pext_attributes)
    ext.pext_loc

let exception_item (exn : Parsetree.type_exception) =
  let ext = exn.ptyexn_constructor in
  item ~name:ext.pext_name.txt ~kind:Exception
    ~deprecated:(has_deprecated ext.pext_attributes)
    ext.pext_loc

let class_type_field_item (field : Parsetree.class_type_field) =
  match field.pctf_desc with
  | Pctf_val (name, _mutable, _virtual, typ) ->
      Some
        (item ~name:name.txt ~kind:Instance_variable
           ~arg_labels:(arg_labels_of typ)
           ~deprecated:(has_deprecated field.pctf_attributes)
           field.pctf_loc)
  | Pctf_method (name, _private, _virtual, typ) ->
      Some
        (item ~name:name.txt ~kind:Method ~arg_labels:(arg_labels_of typ)
           ~deprecated:(has_deprecated field.pctf_attributes)
           field.pctf_loc)
  | Pctf_inherit _ | Pctf_constraint _ | Pctf_attribute _ | Pctf_extension _ ->
      None

let rec class_type_children (typ : Parsetree.class_type) =
  match typ.pcty_desc with
  | Pcty_signature s -> List.filter_map class_type_field_item s.pcsig_fields
  | Pcty_arrow (_, _, typ) | Pcty_open (_, typ) -> class_type_children typ
  | Pcty_constr _ | Pcty_extension _ -> []

let value_item (vd : Parsetree.value_description) =
  item ~name:vd.pval_name.txt ~kind:Value
    ~arg_labels:(arg_labels_of vd.pval_type)
    ~deprecated:(has_deprecated vd.pval_attributes)
    vd.pval_loc

let class_item ~kind (decl : _ Parsetree.class_infos) ~children =
  item ~name:decl.pci_name.txt ~kind ~children
    ~deprecated:(has_deprecated decl.pci_attributes)
    decl.pci_loc

let rec structure_items (structure : Parsetree.structure) =
  List.concat_map structure_item structure

and module_expr_items (mexpr : Parsetree.module_expr) =
  (* Descend through functor abstractions and signature constraints so the
     house-style [module Make (B : S) = struct ... end] machine body is visible
     to outline-based rules. The functor parameter contributes no value items;
     the structure inside the body (possibly behind a [: S] constraint) does.
     [Pmod_ident]/[Pmod_apply] have no inline structure. *)
  match mexpr.pmod_desc with
  | Pmod_structure s -> structure_items s
  | Pmod_functor (_param, body) -> module_expr_items body
  | Pmod_constraint (mexpr, _) -> module_expr_items mexpr
  | _ -> []

and module_binding_item (mb : Parsetree.module_binding) =
  Option.map
    (fun name ->
      item ~name ~kind:Module
        ~children:(module_expr_items mb.pmb_expr)
        ~deprecated:(has_deprecated mb.pmb_attributes)
        mb.pmb_loc)
    mb.pmb_name.txt

and module_type_children (mty : Parsetree.module_type) =
  match mty.pmty_desc with Pmty_signature s -> signature_items s | _ -> []

and module_type_item (mtd : Parsetree.module_type_declaration) =
  item ~name:mtd.pmtd_name.txt ~kind:Module_type
    ~children:
      (match mtd.pmtd_type with
      | Some mty -> module_type_children mty
      | None -> [])
    ~deprecated:(has_deprecated mtd.pmtd_attributes)
    mtd.pmtd_loc

and module_declaration_item (md : Parsetree.module_declaration) =
  Option.map
    (fun name ->
      item ~name ~kind:Module
        ~children:(module_type_children md.pmd_type)
        ~deprecated:(has_deprecated md.pmd_attributes)
        md.pmd_loc)
    md.pmd_name.txt

and structure_item (item : Parsetree.structure_item) =
  match item.pstr_desc with
  | Pstr_value (_, bindings) ->
      List.concat_map
        (fun (vb : Parsetree.value_binding) ->
          pattern_items ~loc:vb.pvb_loc vb.pvb_pat)
        bindings
  | Pstr_primitive vd -> [ value_item vd ]
  | Pstr_type (_, decls) -> List.map type_item decls
  | Pstr_module mb -> Option.to_list (module_binding_item mb)
  | Pstr_recmodule mods -> List.filter_map module_binding_item mods
  | Pstr_modtype mtd -> [ module_type_item mtd ]
  | Pstr_exception exn -> [ exception_item exn ]
  | Pstr_typext te -> List.map extension_item te.ptyext_constructors
  | Pstr_class classes -> List.map (class_item ~kind:Class ~children:[]) classes
  | Pstr_class_type classes ->
      List.map
        (fun (cd : Parsetree.class_type_declaration) ->
          class_item ~kind:Class_type cd
            ~children:(class_type_children cd.pci_expr))
        classes
  | Pstr_eval _ | Pstr_open _ | Pstr_include _ | Pstr_attribute _
  | Pstr_extension _ ->
      []

and signature_items (signature : Parsetree.signature) =
  List.concat_map signature_item signature

and signature_item (item : Parsetree.signature_item) =
  match item.psig_desc with
  | Psig_value vd -> [ value_item vd ]
  | Psig_type (_, decls) | Psig_typesubst decls -> List.map type_item decls
  | Psig_module md -> Option.to_list (module_declaration_item md)
  | Psig_recmodule mods -> List.filter_map module_declaration_item mods
  | Psig_modtype mtd -> [ module_type_item mtd ]
  | Psig_exception exn -> [ exception_item exn ]
  | Psig_typext te -> List.map extension_item te.ptyext_constructors
  | Psig_class classes ->
      List.map
        (fun (cd : Parsetree.class_description) ->
          class_item ~kind:Class cd ~children:(class_type_children cd.pci_expr))
        classes
  | Psig_class_type classes ->
      List.map
        (fun (cd : Parsetree.class_type_declaration) ->
          class_item ~kind:Class_type cd
            ~children:(class_type_children cd.pci_expr))
        classes
  | Psig_open _ | Psig_include _ | Psig_attribute _ | Psig_extension _
  | Psig_modsubst _ | Psig_modtypesubst _ ->
      []

let v = function
  | Ast.Implementation structure -> structure_items structure
  | Ast.Interface signature -> signature_items signature
