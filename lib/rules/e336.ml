(** E336: Pretty-printer naming convention *)

type payload = { function_name : string; expected : string }

(* Match [Format.formatter] (qualified or aliased to [formatter]). *)
let is_formatter (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr
      ( {
          txt = Ldot ({ txt = Lident "Format"; _ }, { txt = "formatter"; _ });
          _;
        },
        [] ) ->
      true
  | Ptyp_constr ({ txt = Lident "formatter"; _ }, []) -> true
  | _ -> false

let is_unit (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "unit"; _ }, []) -> true
  | _ -> false

(* Return [Some value_type] if the given core type matches a printer
   signature [_ Fmt.t] or [Format.formatter -> _ -> unit]. *)
let printer_value_type (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr
      ( { txt = Ldot ({ txt = Lident "Fmt"; _ }, { txt = "t"; _ }); _ },
        [ value ] ) ->
      Some value
  | Ptyp_arrow (Asttypes.Nolabel, fmt, rest) when is_formatter fmt -> (
      match rest.ptyp_desc with
      | Ptyp_arrow (Asttypes.Nolabel, value, ret) when is_unit ret -> Some value
      | _ -> None)
  | _ -> None

(* True when the printer is for the local module's main type [t] -- in that
   case the canonical name is the bare [pp]. *)
let is_local_t (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "t"; _ }, _) -> true
  | _ -> false

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
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  List.filter_map
    (fun (item : Outline.item) ->
      match (item.kind, Outline.parsed_type item) with
      | Outline.Value, Some ct
        when (not (name_matches_convention item.name))
             && Option.is_some (printer_value_type ct) -> (
          let value_type = Option.get (printer_value_type ct) in
          let expected = suggested_name ~name:item.name ~value_type in
          match Outline.location filename item with
          | Some loc ->
              Some (Issue.v ~loc { function_name = item.name; expected })
          | None -> None)
      | _ -> None)
    outline_data

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
