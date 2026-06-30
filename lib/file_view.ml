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

type application_arg = { callee : Merlin.Refs.name option; loc : Location.t }

type application_site = {
  callee : Merlin.Refs.name;
  loc : Location.t;
  args : application_arg list;
}

let typed_expr_callee_name (expr : Typedtree.expression) =
  let rec aux (expr : Typedtree.expression) =
    match expr.exp_desc with
    | Texp_ident (path, _, _) -> Some (name_of_path path)
    | Texp_apply (fn, _) -> aux fn
    | Texp_construct (lid, _, _) -> Some (name_of_longident lid.txt)
    | Texp_struct_item (_, body) -> aux body
    | _ -> None
  in
  aux expr

let application_args args =
  List.filter_map
    (function
      | _, Typedtree.Omitted _ -> None
      | _, Typedtree.Arg (expr : Typedtree.expression) ->
          Some { callee = typed_expr_callee_name expr; loc = expr.exp_loc })
    args

let push_application calls expr fn args =
  Option.iter
    (fun callee ->
      push calls
        { callee; loc = expr.Typedtree.exp_loc; args = application_args args })
    (typed_expr_callee_name fn)

(* A [match] over the protocol message type whose wildcard arm silently
   accepts an unexpected message (the nqsb-tls "Messy State of the Union"
   shape). [loc] is the whole match expression. *)
type message_match = { type_path : Merlin.Refs.name; loc : Location.t }

(* [true] when [pat] is a catch-all wildcard arm: [_] or a plain variable. *)
let rec is_wildcard_pattern : type k. k Typedtree.general_pattern -> bool =
 fun pat ->
  match pat.pat_desc with
  | Tpat_any | Tpat_var _ -> true
  | Tpat_value vp ->
      is_wildcard_pattern (vp :> Typedtree.value Typedtree.general_pattern)
  | _ -> false

(* A catch-all arm SILENTLY ACCEPTS when its result is a normal value -- an [Ok]
   constructor, a tuple, a record, a bare identifier (the state itself), or [()]
   -- so the machine keeps going on a message it should have rejected. Returning
   an [Error] (including via an err-style helper call) or raising is a rejection,
   the correct shape for a catch-all, and is not flagged. Recurse through
   [let]/[open]/sequence/[if]/[match] to the result position(s); every result
   must accept for the arm to count as a silent accept. *)
let rec is_silent_accept (expr : Typedtree.expression) =
  match expr.exp_desc with
  | Texp_construct (lid, _, _) -> (
      match (name_of_longident lid.txt).base with
      | "Ok" | "()" -> true
      | _ -> false)
  | Texp_tuple _ | Texp_record _ | Texp_ident _ -> true
  | Texp_let (_, _, body) | Texp_struct_item (_, body) | Texp_sequence (_, body) ->
      is_silent_accept body
  | Texp_ifthenelse (_, a, Some b) -> is_silent_accept a && is_silent_accept b
  | Texp_match (_, comp_cases, value_cases, _) ->
      let accepts (case : _ Typedtree.case) = is_silent_accept case.c_rhs in
      (comp_cases <> [] || value_cases <> [])
      && List.for_all accepts comp_cases
      && List.for_all accepts value_cases
  | _ -> false

(* Split [s] on the [__] dune-mangling separator (e.g. [Ssh__Message] becomes
   [Ssh; Message]) so the [Message] component is visible whether the path is
   written [Ssh.Message.t] or [Ssh__Message.t]. *)
let split_on_double_underscore s =
  let rec aux acc start i =
    if i + 1 >= String.length s then
      List.rev (String.sub s start (String.length s - start) :: acc)
    else if s.[i] = '_' && s.[i + 1] = '_' then
      aux (String.sub s start (i - start) :: acc) (i + 2) (i + 2)
    else aux acc start (i + 1)
  in
  if s = "" then [ "" ] else aux [] 0 0

(* The scrutinee's type is the protocol message type when its [exp_type] is a
   [Tconstr] whose path has a module component named [Message]
   (e.g. [Ssh.Message.t], [Ssh__Message.t]). *)
let message_type_path (expr : Typedtree.expression) =
  match Typed_types.get_desc expr.exp_type with
  | Typed_types.Tconstr (path, _, _) ->
      let dotted = Typed_path.name path in
      let components =
        dotted |> String.split_on_char '.'
        |> List.concat_map split_on_double_underscore
      in
      if List.mem "Message" components then Some (name_of_path path) else None
  | _ -> None

type walk_result = {
  refs : collected_refs;
  applications : application_site list;
  asserts : Location.t list;  (** [assert ...] expression locations. *)
  message_matches : message_match list;
      (** [match] over the message type with a silent-accept catch-all arm. *)
}

(* Single Tast_iterator pass that populates the resolved-references
   accumulator AND the application-site list. Replaces what used to be
   two separate iterator passes ([collect_resolved] + [lazy_applications])
   over the same typedtree. *)
(* A [match] over the message type is flagged when a catch-all wildcard arm
   silently accepts the unexpected message (its body returns a normal value
   rather than rejecting it). A catch-all that rejects -- [| _ -> Error _],
   [| s -> Error (`Unexpected s)] -- is the correct shape and is not flagged. *)
let message_match_of ~scrutinee value_cases =
  match message_type_path scrutinee with
  | None -> None
  | Some type_path ->
      List.find_map
        (fun (case : _ Typedtree.case) ->
          if is_wildcard_pattern case.c_lhs && is_silent_accept case.c_rhs then
            Some (type_path, case.c_lhs.pat_loc)
          else None)
        value_cases

let collect_walk ~filename (tree : Merlin.typedtree) =
  let acc = refs_acc () in
  let calls = ref [] in
  let asserts = ref [] in
  let message_matches = ref [] in
  let iterator =
    {
      Tast_iterator.default_iterator with
      expr =
        (fun this (expr : Typedtree.expression) ->
          (match expr.exp_desc with
          | Texp_apply (fn, args) -> push_application calls expr fn args
          | Texp_assert _ -> asserts := expr.exp_loc :: !asserts
          | Texp_match (scrutinee, cases, _, _) -> (
              (* The 2nd field is the full case list; a pure value match leaves
                 the 3rd (value-only) field empty, so read the cases here. *)
              match message_match_of ~scrutinee cases with
              | Some (type_path, loc) ->
                  message_matches := { type_path; loc } :: !message_matches
              | None -> ())
          | _ -> ());
          iter_typed_expr ~filename acc this expr);
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
  {
    refs = collected_refs_of_acc acc;
    applications = List.rev !calls;
    asserts = List.rev !asserts;
    message_matches = List.rev !message_matches;
  }

type file_item_kind =
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

type doc = { text : string; loc : Location.t }

type file_item = {
  name : string;
  kind : file_item_kind;
  loc : Location.t;
  deprecated : bool;
  doc : doc option;
  deriving : string list;
  type_ : Typed_types.type_expr option;
  children : file_item list;
  mutable_field : bool;  (** [true] for a [mutable] record field. *)
}

type t = {
  filename : string;
  lock : Eio.Mutex.t;
  typedtree : Merlin.typedtree option Lazy.t;
  values : Function_metrics.value list Lazy.t;
  reference_outline : collected_refs Lazy.t;
  items : file_item list Lazy.t;
  resolved : collected_refs option Lazy.t;
  module_names : string list Lazy.t;
  applications : application_site list Lazy.t;
  asserts : Location.t list Lazy.t;
      (** Cache of every typed application site whose head is a path identifier.
          One typedtree walk per file regardless of how many rules call
          {!iter_applications}. *)
  message_matches : message_match list Lazy.t;
      (** Cache of every message-type [match] with a silent-accept wildcard arm.
      *)
}

let force t lazy_value =
  Eio.Mutex.lock t.lock;
  Fun.protect
    ~finally:(fun () -> Eio.Mutex.unlock t.lock)
    (fun () -> Lazy.force lazy_value)

let lazy_typedtree ~filename typedtree =
  lazy
    (match typedtree () with
    | Ok (Some _ as tree) -> tree
    | Ok None -> None
    | Error msg ->
        Log.warn (fun m ->
            m
              "Failed to load typedtree for %s: %s; typedtree-backed rules are \
               skipped for this file. Run dune build @check before merlint so \
               the .cmt/.cmti artefact exists and is up to date."
              filename msg);
        fail "%s" msg)

let lazy_walk ~filename ~typedtree =
  lazy
    (match Lazy.force typedtree with
    | Some tree -> Some (collect_walk ~filename tree)
    | None -> None)

let lazy_reference_outline walk =
  lazy
    (match Lazy.force walk with
    | Some (walk : walk_result) -> walk.refs
    | None -> empty_refs)

let lazy_resolved walk =
  lazy
    (match Lazy.force walk with
    | Some (walk : walk_result) -> Some walk.refs
    | None -> None)

let lazy_applications walk =
  lazy
    (match Lazy.force walk with
    | Some (walk : walk_result) -> walk.applications
    | None -> [])

let lazy_asserts walk =
  lazy
    (match Lazy.force walk with
    | Some (walk : walk_result) -> walk.asserts
    | None -> [])

let lazy_message_matches walk =
  lazy
    (match Lazy.force walk with
    | Some (walk : walk_result) -> walk.message_matches
    | None -> [])

let typed_has_deprecated attrs =
  List.exists
    (fun (attr : Parsetree.attribute) ->
      attr.attr_name.txt = "deprecated"
      || attr.attr_name.txt = "ocaml.deprecated")
    attrs

let doc_payload_string (payload : Parsetree.payload) =
  match payload with
  | PStr
      [
        {
          pstr_desc =
            Pstr_eval
              ( {
                  pexp_desc =
                    Pexp_constant { pconst_desc = Pconst_string (doc, _, _); _ };
                  _;
                },
                _ );
          _;
        };
      ] ->
      Some doc
  | _ -> None

let typed_doc attrs =
  List.find_map
    (fun (attr : Parsetree.attribute) ->
      if attr.attr_name.txt = "ocaml.doc" then
        Some
          {
            text =
              Option.value ~default:"" (doc_payload_string attr.attr_payload)
              |> String.trim;
            loc = attr.attr_loc;
          }
      else None)
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

let typed_item ~name ~kind ?type_ ?doc ?(children = []) ?(deriving = [])
    ?(deprecated = false) ?(mutable_field = false) loc =
  { name; kind; loc; deprecated; doc; deriving; type_; children; mutable_field }

let rec typed_pattern_items ?loc (pat : Typedtree.pattern) =
  let loc = Option.value loc ~default:pat.pat_loc in
  match pat.pat_desc with
  | Tpat_var (_ident, name, _) ->
      [ typed_item ~name:name.txt ~kind:Value ~type_:pat.pat_type loc ]
  | Tpat_alias (p, _ident, name, _, _) ->
      typed_item ~name:name.txt ~kind:Value ~type_:pat.pat_type loc
      :: typed_pattern_items ~loc p
  | Tpat_tuple fields ->
      List.concat_map (fun (_, p) -> typed_pattern_items ~loc p) fields
  | Tpat_construct (_, _, args, _) ->
      List.concat_map (typed_pattern_items ~loc) args
  | Tpat_variant (_, arg, _) -> (
      match arg with None -> [] | Some p -> typed_pattern_items ~loc p)
  | Tpat_record (fields, _) ->
      List.concat_map (fun (_, _, p) -> typed_pattern_items ~loc p) fields
  | Tpat_array (_, pats) -> List.concat_map (typed_pattern_items ~loc) pats
  | Tpat_or (lhs, rhs, _) ->
      typed_pattern_items ~loc lhs @ typed_pattern_items ~loc rhs
  | Tpat_lazy p -> typed_pattern_items ~loc p
  | Tpat_any | Tpat_constant _ -> []

let typed_type_children (decl : Typedtree.type_declaration) =
  match decl.typ_kind with
  | Ttype_record labels ->
      List.map
        (fun (ld : Typedtree.label_declaration) ->
          typed_item ~name:ld.ld_name.txt ~kind:Field
            ~type_:ld.ld_type.ctyp_type
            ~deprecated:(typed_has_deprecated ld.ld_attributes)
            ~mutable_field:
              (match ld.ld_mutable with Mutable -> true | Immutable -> false)
            ld.ld_loc)
        labels
  | Ttype_variant constructors ->
      List.map
        (fun (cd : Typedtree.constructor_declaration) ->
          typed_item ~name:cd.cd_name.txt ~kind:Constructor
            ~deprecated:(typed_has_deprecated cd.cd_attributes)
            cd.cd_loc)
        constructors
  | Ttype_abstract | Ttype_open | Ttype_external _ -> []

let typed_type_item (decl : Typedtree.type_declaration) =
  typed_item ~name:decl.typ_name.txt ~kind:Type
    ?type_:
      (Option.map
         (fun (ct : Typedtree.core_type) -> ct.ctyp_type)
         decl.typ_manifest)
    ?doc:(typed_doc decl.typ_attributes)
    ~deriving:(deriving_names decl.typ_attributes)
    ~children:(typed_type_children decl)
    ~deprecated:(typed_has_deprecated decl.typ_attributes)
    decl.typ_loc

let typed_extension_item (ext : Typedtree.extension_constructor) =
  typed_item ~name:ext.ext_name.txt ~kind:Extension
    ?doc:(typed_doc ext.ext_attributes)
    ~deprecated:(typed_has_deprecated ext.ext_attributes)
    ext.ext_loc

let typed_exception_item (exn : Typedtree.type_exception) =
  let ext = exn.tyexn_constructor in
  typed_item ~name:ext.ext_name.txt ~kind:Exception
    ?doc:(typed_doc ext.ext_attributes)
    ~deprecated:(typed_has_deprecated ext.ext_attributes)
    ext.ext_loc

let typed_class_type_field_item (field : Typedtree.class_type_field) =
  match field.ctf_desc with
  | Tctf_val (name, _mutable, _virtual, typ) ->
      Some
        (typed_item ~name ~kind:Instance_variable ~type_:typ.ctyp_type
           ?doc:(typed_doc field.ctf_attributes)
           ~deprecated:(typed_has_deprecated field.ctf_attributes)
           field.ctf_loc)
  | Tctf_method (name, _private, _virtual, typ) ->
      Some
        (typed_item ~name ~kind:Method ~type_:typ.ctyp_type
           ?doc:(typed_doc field.ctf_attributes)
           ~deprecated:(typed_has_deprecated field.ctf_attributes)
           field.ctf_loc)
  | Tctf_inherit _ | Tctf_constraint _ | Tctf_attribute _ -> None

let typed_class_signature_items (signature : Typedtree.class_signature) =
  List.filter_map typed_class_type_field_item signature.csig_fields

let rec typed_class_type_children (typ : Typedtree.class_type) =
  match typ.cltyp_desc with
  | Tcty_signature s -> typed_class_signature_items s
  | Tcty_arrow (_, _, typ) | Tcty_open (_, typ) -> typed_class_type_children typ
  | Tcty_constr _ -> []

let rec typed_structure_items (structure : Typedtree.structure) =
  List.concat_map typed_structure_item structure.str_items

and typed_module_expr_items (mexpr : Typedtree.module_expr) =
  (* Descend through functor abstractions and signature constraints so the
     house-style [module Make (B : S) = struct ... end] machine body is
     visible to outline-based rules. The functor parameter contributes no
     value items; the structure inside the body (possibly behind a [: S]
     constraint) does. [Tmod_ident]/[Tmod_apply] have no inline structure. *)
  match mexpr.mod_desc with
  | Tmod_structure s -> typed_structure_items s
  | Tmod_functor (_param, body) -> typed_module_expr_items body
  | Tmod_constraint (mexpr, _, _, _) -> typed_module_expr_items mexpr
  | _ -> []

and typed_module_binding_item (mb : Typedtree.module_binding) =
  Option.map
    (fun name ->
      let children = typed_module_expr_items mb.mb_expr in
      typed_item ~name ~kind:Module ~children
        ?doc:(typed_doc mb.mb_attributes)
        ~deprecated:(typed_has_deprecated mb.mb_attributes)
        mb.mb_loc)
    mb.mb_name.txt

and typed_structure_item (item : Typedtree.structure_item) =
  match item.str_desc with
  | Tstr_value (_, bindings) ->
      List.concat_map
        (fun (vb : Typedtree.value_binding) ->
          typed_pattern_items ~loc:vb.vb_loc vb.vb_pat)
        bindings
  | Tstr_primitive vd ->
      [
        typed_item ~name:vd.val_name.txt ~kind:Value
          ~type_:vd.val_desc.ctyp_type
          ?doc:(typed_doc vd.val_attributes)
          ~deprecated:(typed_has_deprecated vd.val_attributes)
          vd.val_loc;
      ]
  | Tstr_type (_, decls) -> List.map typed_type_item decls
  | Tstr_module mb ->
      Option.fold (typed_module_binding_item mb) ~none:[] ~some:(fun item ->
          [ item ])
  | Tstr_recmodule mods -> List.filter_map typed_module_binding_item mods
  | Tstr_modtype mtd ->
      [
        typed_item ~name:mtd.mtd_name.txt ~kind:Module_type
          ~children:
            (match mtd.mtd_type with
            | Some { mty_desc = Tmty_signature s; _ } -> typed_signature_items s
            | _ -> [])
          ?doc:(typed_doc mtd.mtd_attributes)
          ~deprecated:(typed_has_deprecated mtd.mtd_attributes)
          mtd.mtd_loc;
      ]
  | Tstr_exception exn -> [ typed_exception_item exn ]
  | Tstr_typext te -> List.map typed_extension_item te.tyext_constructors
  | Tstr_class classes ->
      List.map
        (fun ((cd, _) : Typedtree.class_declaration * string list) ->
          typed_item ~name:cd.ci_id_name.txt ~kind:Class
            ?doc:(typed_doc cd.ci_attributes)
            ~deprecated:(typed_has_deprecated cd.ci_attributes)
            cd.ci_loc)
        classes
  | Tstr_class_type classes ->
      List.map
        (fun ((_, name, cd) :
               Typed_ident.t
               * string Ocaml_parsing.Asttypes.loc
               * Typedtree.class_type_declaration) ->
          typed_item ~name:name.txt ~kind:Class_type
            ~children:(typed_class_type_children cd.ci_expr)
            ?doc:(typed_doc cd.ci_attributes)
            ~deprecated:(typed_has_deprecated cd.ci_attributes)
            cd.ci_loc)
        classes
  | Tstr_eval _ | Tstr_open _ | Tstr_include _ | Tstr_attribute _ -> []

and typed_signature_items (signature : Typedtree.signature) =
  List.concat_map typed_signature_item signature.sig_items

and typed_recmodule_item (md : Typedtree.module_declaration) =
  Option.map
    (fun name ->
      typed_item ~name ~kind:Module
        ~children:
          (match md.md_type.mty_desc with
          | Tmty_signature s -> typed_signature_items s
          | _ -> [])
        ?doc:(typed_doc md.md_attributes)
        ~deprecated:(typed_has_deprecated md.md_attributes)
        md.md_loc)
    md.md_name.txt

and typed_signature_item (item : Typedtree.signature_item) =
  match item.sig_desc with
  | Tsig_value vd ->
      [
        typed_item ~name:vd.val_name.txt ~kind:Value
          ~type_:vd.val_desc.ctyp_type
          ?doc:(typed_doc vd.val_attributes)
          ~deprecated:(typed_has_deprecated vd.val_attributes)
          vd.val_loc;
      ]
  | Tsig_type (_, decls) | Tsig_typesubst decls ->
      List.map typed_type_item decls
  | Tsig_module md ->
      Option.fold md.md_name.txt ~none:[] ~some:(fun name ->
          [
            typed_item ~name ~kind:Module
              ~children:
                (match md.md_type.mty_desc with
                | Tmty_signature s -> typed_signature_items s
                | _ -> [])
              ?doc:(typed_doc md.md_attributes)
              ~deprecated:(typed_has_deprecated md.md_attributes)
              md.md_loc;
          ])
  | Tsig_recmodule mods -> List.filter_map typed_recmodule_item mods
  | Tsig_modtype mtd ->
      [
        typed_item ~name:mtd.mtd_name.txt ~kind:Module_type
          ~children:
            (match mtd.mtd_type with
            | Some { mty_desc = Tmty_signature s; _ } -> typed_signature_items s
            | _ -> [])
          ?doc:(typed_doc mtd.mtd_attributes)
          ~deprecated:(typed_has_deprecated mtd.mtd_attributes)
          mtd.mtd_loc;
      ]
  | Tsig_exception exn -> [ typed_exception_item exn ]
  | Tsig_typext te -> List.map typed_extension_item te.tyext_constructors
  | Tsig_class classes ->
      List.map
        (fun (cd : Typedtree.class_description) ->
          typed_item ~name:cd.ci_id_name.txt ~kind:Class
            ~children:(typed_class_type_children cd.ci_expr)
            ?doc:(typed_doc cd.ci_attributes)
            ~deprecated:(typed_has_deprecated cd.ci_attributes)
            cd.ci_loc)
        classes
  | Tsig_class_type classes ->
      List.map
        (fun (cd : Typedtree.class_type_declaration) ->
          typed_item ~name:cd.ci_id_name.txt ~kind:Class_type
            ~children:(typed_class_type_children cd.ci_expr)
            ?doc:(typed_doc cd.ci_attributes)
            ~deprecated:(typed_has_deprecated cd.ci_attributes)
            cd.ci_loc)
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

let is_module_name name =
  String.length name > 0
  && Char.uppercase_ascii name.[0] = name.[0]
  && Char.lowercase_ascii name.[0] <> name.[0]

let add_module_name acc name = if is_module_name name then name :: acc else acc

let module_names_of_name (name : Merlin.Refs.name) acc =
  List.fold_left add_module_name (add_module_name acc name.base) name.prefix

let module_names_of_ref acc (elt : Merlin.Refs.elt) =
  module_names_of_name elt.name acc

let lazy_module_names reference_outline =
  lazy
    (let outline : collected_refs = Lazy.force reference_outline in
     let refs : Merlin.Refs.t = outline.refs in
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
  let walk = lazy_walk ~filename ~typedtree in
  let reference_outline = lazy_reference_outline walk in
  let items = lazy_items typedtree in
  let resolved = lazy_resolved walk in
  let module_names = lazy_module_names reference_outline in
  let applications = lazy_applications walk in
  let asserts = lazy_asserts walk in
  let message_matches = lazy_message_matches walk in
  {
    filename;
    lock = Eio.Mutex.create ();
    typedtree;
    values;
    reference_outline;
    items;
    resolved;
    module_names;
    applications;
    asserts;
    message_matches;
  }

let filename t = t.filename
let pp ppf t = Fmt.string ppf t.filename
let typedtree t = force t t.typedtree
let values t = force t t.values
let is_resolved t = Option.is_some (force t t.typedtree)

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

  (* OCaml 5.5 wraps function argument types in [Tpoly (_, [])] even when no
     polymorphism is present. Peel those identity wrappers so the leaf
     inspectors below see the underlying [Tconstr]/[Tarrow]/etc. *)
  let rec desc ct =
    match Typed_types.get_desc ct with
    | Typed_types.Tpoly (body, _) -> desc body
    | d -> d

  let arrow ct =
    match desc ct with
    | Typed_types.Tarrow (label, dom, ret, _) -> Some (label, dom, ret)
    | _ -> None

  let is_function (ct : t) = Option.is_some (arrow ct)

  let is_variable ct =
    match desc ct with
    | Typed_types.Tvar _ | Typed_types.Tunivar _ -> true
    | _ -> false

  let tuple ct =
    match desc ct with
    | Typed_types.Ttuple fields -> Some (List.map snd fields)
    | _ -> None

  let constr ct =
    match desc ct with
    | Typed_types.Tconstr (path, args, _) -> Some (name_of_path path, args)
    | _ -> None

  let constr_path ct =
    match desc ct with
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
    match desc ct with
    | Typed_types.Tarrow (_, _, ret, _) -> return_type ret
    | _ -> Some ct

  let rec returns_option (ct : t) =
    match desc ct with
    | Typed_types.Tarrow (_, _, ret, _) -> returns_option ret
    | Typed_types.Tconstr (path, _, _) ->
        Typed_path.same path Typed_predef.path_option
        || name_of_path path |> fun n ->
           Name.equals_path n [ "Stdlib"; "option" ]
    | _ -> false

  let count_unlabelled (ct : t) ~match_ =
    let rec aux acc (ct : t) =
      match desc ct with
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
        match constr ct with Some (name, []) -> Name.pp ppf name | _ -> ())
    | s -> Fmt.string ppf s
end

(* {2 Item} *)

module Doc = struct
  type t = { doc : doc; filename : string }

  let text t = t.doc.text
  let loc t = Loc.of_typed ~filename:t.filename t.doc.loc
end

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
    | Extension
    | Field
    | Method
    | Instance_variable

  type t = { item : file_item; filename : string }

  let kind_of_item : file_item_kind -> kind = function
    | Value -> Value
    | Type -> Type
    | Module -> Module
    | Module_type -> Module_type
    | Class -> Class
    | Class_type -> Class_type
    | Constructor -> Constructor
    | Exception -> Exception
    | Extension -> Extension
    | Field -> Field
    | Method -> Method
    | Instance_variable -> Instance_variable

  let name (t : t) = t.item.name
  let kind (t : t) = kind_of_item t.item.kind
  let equal_kind (a : kind) (b : kind) = a = b
  let deprecated (t : t) = t.item.deprecated
  let loc (t : t) = Loc.of_typed ~filename:t.filename t.item.loc

  let doc (t : t) =
    Option.map (fun doc -> { Doc.doc; filename = t.filename }) t.item.doc

  let derives (t : t) name = List.mem name t.item.deriving
  let type_sig (t : t) = t.item.type_
  let is_mutable_field (t : t) = t.item.mutable_field

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
  type arg = {
    callee : Merlin.Refs.name option;
    loc : Location.t;
    filename : string;
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
    let loc a = Loc.of_typed ~filename:a.filename a.loc

    let is_call (a : arg) ~path =
      match a.callee with
      | None -> false
      | Some name -> Name.equals_path name path
  end
end

(* {2 Message_match} *)

module Message_match = struct
  type t = { type_path : Merlin.Refs.name; loc : Merlin.Location.t }

  let type_path t = t.type_path
  let loc t = t.loc
end

(* {2 Top-level accessors} *)

let items t =
  List.map (fun item -> { Item.item; filename = t.filename }) (force t t.items)

let rec flatten_items items =
  List.concat_map (fun item -> item :: flatten_items (Item.children item)) items

let all_items t = flatten_items (items t)

let value_items t =
  List.filter (fun item -> Item.kind item = Item.Value) (all_items t)

let outline_refs t = (force t t.reference_outline).refs
let outline_identifiers t = (outline_refs t).identifiers
let outline_patterns t = (outline_refs t).patterns
let outline_variants t = (outline_refs t).variants

let outline_variant_definitions t =
  (force t t.reference_outline).variant_definitions

let outline_modules t = (outline_refs t).modules

let outline_module_definitions t =
  (force t t.reference_outline).module_definitions

let outline_types t = (outline_refs t).types
let outline_type_definitions t = (force t t.reference_outline).type_definitions
let outline_exceptions t = (outline_refs t).exceptions
let outline_values t = (outline_refs t).values

let resolved_identifiers t =
  Option.map
    (fun (d : collected_refs) -> d.refs.identifiers)
    (force t t.resolved)

let resolved_patterns t =
  Option.map (fun (d : collected_refs) -> d.refs.patterns) (force t t.resolved)

let resolved_variants t =
  Option.map (fun (d : collected_refs) -> d.refs.variants) (force t t.resolved)

let resolved_modules t =
  Option.map (fun (d : collected_refs) -> d.refs.modules) (force t t.resolved)

let resolved_types t =
  Option.map (fun (d : collected_refs) -> d.refs.types) (force t t.resolved)

let resolved_exceptions t =
  Option.map
    (fun (d : collected_refs) -> d.refs.exceptions)
    (force t t.resolved)

let resolved_values t =
  Option.map (fun (d : collected_refs) -> d.refs.values) (force t t.resolved)

let resolved_signatures t =
  Option.map
    (fun (d : collected_refs) -> d.refs.value_sigs)
    (force t t.resolved)

let referenced_module_names t = force t t.module_names

let iter_applications t f =
  force t t.applications
  |> List.iter (fun { callee; loc; args } ->
      let loc = Loc.of_typed ~filename:t.filename loc in
      let args =
        let arg (arg : application_arg) : Call.arg =
          { callee = arg.callee; loc = arg.loc; filename = t.filename }
        in
        List.map arg args
      in
      let call = { Call.callee; args; loc } in
      f call)

let iter_asserts t f =
  force t t.asserts
  |> List.iter (fun loc -> f (Loc.of_typed ~filename:t.filename loc))

let iter_message_matches t f =
  force t t.message_matches
  |> List.iter (fun { type_path; loc } ->
      f { Message_match.type_path; loc = Loc.of_typed ~filename:t.filename loc })

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
