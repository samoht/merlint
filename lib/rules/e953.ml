(** E953: Encoding verb vocabulary. *)

module FV = File_view
module P = Project_index.Package
module L = Project_index.Library

type payload = { module_ : string; verb : string; canonical : string }

(* Bare anti-pattern entry-point names, each mapped to the canonical verb from
   the ocaml-encodings six-verb surface (of_string / to_string / of_reader /
   to_writer for I/O; decode / encode over the AST). Only exact names are
   rejected: the prefixed [parse_value] / [print_node] helpers are internal
   plumbing and are left alone. *)
let bare_synonyms =
  [
    ("parse", "of_string");
    ("from_string", "of_string");
    ("unmarshal", "of_string");
    ("read", "of_reader");
    ("input", "of_reader");
    ("print", "to_string");
    ("unparse", "to_string");
    ("marshal", "to_string");
    ("write", "to_writer");
    ("output", "to_writer");
  ]

let canonical_of name =
  List.assoc_opt (String.lowercase_ascii name) bare_synonyms

(* The codec core is I/O-free; an [eio]-tagged sibling adapter is out of scope,
   matching how E946 treats protocol packages. *)
let is_codec_pkg pkg =
  let tags = P.tags pkg in
  List.mem "codec" tags && not (List.mem "eio" tags)

type module_ = { module_name : string; file : Context.path }

(* The top-level module of each library in a codec package: the [.ml] whose
   basename matches the library name (the [foo.ml] of library [foo]). The six
   verbs live there; the AST and codec layers ([value.ml], [codec.ml]) keep
   their own descriptive names. *)
let toplevel_modules ctx =
  Context.index ctx |> Project_index.source_package_list
  |> List.filter is_codec_pkg
  |> List.concat_map (fun pkg ->
      Project_index.package_libraries pkg
      |> List.concat_map (fun lib ->
          let lname = L.name lib in
          L.files lib
          |> List.filter_map (fun f ->
              if
                Fpath.has_ext ".ml" f
                && Filename.remove_extension (Fpath.basename f) = lname
              then Some { module_name = lname; file = Context.resolve ctx f }
              else None)))

let check (ctx : Context.project) (m : module_) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        FV.all_items view
        |> List.filter_map (fun item ->
            match FV.Item.kind item with
            | FV.Item.Value -> (
                let name = FV.Item.name item in
                match canonical_of name with
                | Some canonical ->
                    Some
                      (Issue.v ~loc:(FV.Item.loc item)
                         { module_ = m.module_name; verb = name; canonical })
                | None -> None)
            | _ -> None)

let enumerate ctx = toplevel_modules ctx

let pp ppf { module_; verb; canonical } =
  Fmt.pf ppf
    "%s.%s is not a canonical encoding verb. Rename it to %s; a codec's \
     top-level entry points are of_string / to_string / of_reader / to_writer \
     (and decode / encode over the AST), and the parse / from_string / print / \
     read / write synonyms are rejected."
    (String.capitalize_ascii module_)
    verb canonical

let rule =
  Rule.v ~code:"E953" ~title:"Encoding verb vocabulary"
    ~category:Rule.Naming_conventions
    ~hint:
      "A data-codec package (tagged codec) exposes its top-level entry points \
       from a fixed vocabulary: of_string / to_string / of_reader / to_writer \
       for I/O, and decode / encode over the AST, each of_/decode with an _exn \
       twin (never a ' variant). The bare synonyms parse / from_string / \
       unmarshal / print / unparse / marshal / read / input / write / output \
       are rejected -- each maps to a canonical verb. The prefixed parse_* / \
       print_* helpers are internal and left alone. See E945 for the codec/AST \
       layering, E948 for the protocol verb vocabulary."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
