(** E336: Pretty-printer naming convention *)

type payload = { function_name : string; expected : string }

let is_formatter typ =
  File_view.Type_view.is_constr typ ~path:[ "Format"; "formatter" ]

(* Return [Some value_type] if the given core type matches a printer
   signature [_ Fmt.t] or [Format.formatter -> _ -> unit]. *)
let printer_value_type typ =
  match File_view.Type_view.constr typ with
  | Some (name, [ value ]) when File_view.Name.equals_path name [ "Fmt"; "t" ]
    ->
      Some value
  | _ -> (
      match File_view.Type_view.arrow typ with
      | Some (Ocaml_parsing.Asttypes.Nolabel, fmt, rest) when is_formatter fmt
        -> (
          match File_view.Type_view.arrow rest with
          | Some (Ocaml_parsing.Asttypes.Nolabel, value, ret)
            when File_view.Type_view.is_unit ret ->
              Some value
          | _ -> None)
      | _ -> None)

(* True when the printer is for the local module's main type [t] -- in that
   case the canonical name is the bare [pp]. *)
let is_local_t typ =
  match File_view.Type_view.constr typ with
  | Some (name, _) -> File_view.Name.base name = "t"
  | None -> false

(* Suggested rename. When the printer is for the local [t], canonical name
   is [pp]. Otherwise prefix the existing name with [pp_] so the
   developer's intended distinction (e.g. [dump] vs [render]) is preserved
   as the suffix. *)
let suggested_name ~name ~value_type =
  if is_local_t value_type then "pp" else "pp_" ^ name

(* [pp]/[pp_*] is the OCaml convention; [dump]/[dump_*] is also accepted as
   an in-tree convention for human-readable diagnostic dumps. *)
let name_matches_convention name =
  name = "pp"
  || String.starts_with ~prefix:"pp_" name
  || name = "dump"
  || String.starts_with ~prefix:"dump_" name

let check (ctx : Context.file) =
  List.filter_map
    (fun item ->
      let module Item = File_view.Item in
      match (Item.kind item, Item.type_sig item) with
      | Item.Value, Some typ when not (name_matches_convention (Item.name item))
        -> (
          match printer_value_type typ with
          | None -> None
          | Some value_type ->
              let expected =
                suggested_name ~name:(Item.name item) ~value_type
              in
              Some
                (Issue.v ~loc:(Item.loc item)
                   { function_name = Item.name item; expected }))
      | _ -> None)
    (File_view.typed_items (Context.view ctx))

let pp ppf { function_name; expected } =
  Fmt.pf ppf
    "Pretty-printer '%s' should be named '%s' (functions of type [_ Fmt.t] or \
     [Format.formatter -> _ -> unit] use the [pp]/[pp_<type>] convention)"
    function_name expected

let rule =
  Rule.v ~code:"E336" ~title:"Pretty-printer naming"
    ~category:Naming_conventions
    ~hint:
      "Pretty-printers — values of type [_ Fmt.t] or [Format.formatter -> _ -> \
       unit] — follow a fixed naming convention: [pp] when the value type is \
       the module's main type [t], and [pp_<type>] otherwise. The convention \
       matches [Fmt.pp_print_*] and [Format.pp_print_*] in the stdlib."
    ~examples:
      [ Example.bad Examples.E336.bad_ml; Example.good Examples.E336.good_ml ]
    ~pp (File check)
