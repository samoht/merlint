(* Bare [Parsetree] and [Ast_iterator] here are compiler-libs': the tree walked
   is the one {!Ast} parsed with the stock parser, which is the only parser that
   emits docstrings at all -- merlin's vendored lexer has them switched off. *)

let payload_string (payload : Parsetree.payload) =
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

type comment = { text : string; loc : Location.t }
type t = { by_range : (int * int, comment) Hashtbl.t }

let position (p : Lexing.position) =
  { Location.line = p.pos_lnum; col = p.pos_cnum - p.pos_bol }

let merlin_loc ~filename (loc : Warnings.loc) =
  {
    Location.file = filename;
    start = position loc.loc_start;
    end_ = position loc.loc_end;
  }

(* [ocaml.text] is a floating comment -- a section header between declarations,
   not documentation of the one that follows -- so only [ocaml.doc] counts. *)
let comment_of ~filename attrs =
  List.find_map
    (fun (attr : Parsetree.attribute) ->
      if attr.attr_name.txt = "ocaml.doc" then
        Some
          {
            text =
              Option.value ~default:"" (payload_string attr.attr_payload)
              |> String.trim;
            loc = merlin_loc ~filename attr.attr_loc;
          }
      else None)
    attrs

let record t ~filename (loc : Warnings.loc) attrs =
  match comment_of ~filename attrs with
  | None -> ()
  | Some comment ->
      Hashtbl.replace t.by_range
        (loc.loc_start.pos_cnum, loc.loc_end.pos_cnum)
        comment

(* Every declaration that can carry a doc comment, in an interface and in an
   implementation alike. [default_iterator] walks the nesting -- a signature
   inside a module type, a class type's fields -- so only the leaves are named
   here. *)
let iterator t ~filename =
  let open Ast_iterator in
  let note loc attrs = record t ~filename loc attrs in
  {
    default_iterator with
    value_description =
      (fun this vd ->
        note vd.pval_loc vd.pval_attributes;
        default_iterator.value_description this vd);
    type_declaration =
      (fun this td ->
        note td.ptype_loc td.ptype_attributes;
        default_iterator.type_declaration this td);
    constructor_declaration =
      (fun this cd ->
        note cd.pcd_loc cd.pcd_attributes;
        default_iterator.constructor_declaration this cd);
    label_declaration =
      (fun this ld ->
        note ld.pld_loc ld.pld_attributes;
        default_iterator.label_declaration this ld);
    module_declaration =
      (fun this md ->
        note md.pmd_loc md.pmd_attributes;
        default_iterator.module_declaration this md);
    module_type_declaration =
      (fun this mtd ->
        note mtd.pmtd_loc mtd.pmtd_attributes;
        default_iterator.module_type_declaration this mtd);
    extension_constructor =
      (fun this ec ->
        note ec.pext_loc ec.pext_attributes;
        default_iterator.extension_constructor this ec);
    value_binding =
      (fun this vb ->
        note vb.pvb_loc vb.pvb_attributes;
        default_iterator.value_binding this vb);
    module_binding =
      (fun this mb ->
        note mb.pmb_loc mb.pmb_attributes;
        default_iterator.module_binding this mb);
  }

let v ~filename ast =
  let t = { by_range = Hashtbl.create 64 } in
  let it = iterator t ~filename in
  (match ast with
  | Ast.Interface signature -> it.signature it signature
  | Ast.Implementation structure -> it.structure it structure);
  t

let find t ~start ~stop = Hashtbl.find_opt t.by_range (start, stop)
