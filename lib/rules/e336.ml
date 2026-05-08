(** E336: Pretty-printer naming convention *)

type payload = { function_name : string; expected : string }

(** Match [Format.formatter] (qualified or aliased to [formatter]). *)
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

(** Stem of a value type for naming: ["t"] -> [None] (use bare ["pp"]); a
    user-named constructor or a path's tail produces the suffix. *)
let stem_of_type (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt; _ }, _) -> (
      match txt with
      | Lident "t" -> Some `Bare
      | Lident name -> Some (`Suffix name)
      | Ldot (_, { txt = "t"; _ }) -> Some `Bare
      | Ldot (_, { txt = name; _ }) -> Some (`Suffix name)
      | Lapply _ -> None)
  | _ -> None

(** Return [Some value_type] if the given core type matches a printer signature
    [_ Fmt.t] or [Format.formatter -> _ -> unit]. *)
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

let expected_name value_type =
  match stem_of_type value_type with
  | Some `Bare -> Some "pp"
  | Some (`Suffix s) -> Some ("pp_" ^ s)
  | None -> None

(** Accept any name that follows the [pp]/[pp_*] shape. The type-driven
    [expected] is only used as a suggestion in the error message, since type
    aliases ([type t = int]) get elaborated away by merlin and would cause false
    positives if matched exactly. *)
let name_matches_convention name =
  name = "pp" || String.starts_with ~prefix:"pp_" name

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
          match (expected_name value_type, Outline.location filename item) with
          | Some expected, Some loc ->
              Some (Issue.v ~loc { function_name = item.name; expected })
          | _ -> None)
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
