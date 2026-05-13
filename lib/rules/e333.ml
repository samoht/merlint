(** E333: Prefer [<dst>_of_<src>] over [<src>_to_<dst>] / [<dst>_from_<src>] *)

type kind =
  | Sep_or_t_pattern
  | To_prefix_non_t of {
      src_type_name : string;
      src_type_pretty : string;
      polymorphic_arg : bool;
          (** [true] when the source is a constructor with a polymorphic
              argument (['a list], ['a option], ['a Hashtbl.t]). The diagnostic
              still flags the function (the convention isn't met), but
              suppresses the [<X>_of_<head>] rename suggestion because it would
              hide the polymorphic parameter and read worse than [to_<X>]. *)
    }
      (** Which sub-rule fired. [Sep_or_t_pattern] is the
          [_to_]/[_from_]/[_of_t] family where renaming the function is the only
          fix. [To_prefix_non_t] is [to_<X>] with a non-[t] source type, where
          the recommended fix is to declare [type t = <source>] in the module so
          the function reads as [t -> X] -- renaming the function is a fallback.
      *)

type payload = { function_name : string; suggested : string; kind : kind }

(** Split [name] on [sep]. Returns [Some (left, right)] when the name has
    exactly one occurrence of [sep], non-empty halves, and [right] is a single
    snake_case word not starting with a digit. *)
let split_separator_pattern ~sep name =
  match Astring.String.cuts ~sep name with
  | [ left; right ]
    when left <> "" && right <> ""
         && (not (String.contains right '_'))
         && not (right.[0] >= '0' && right.[0] <= '9') ->
      Some (left, right)
  | _ -> None

(** Strip leading [~lab:T] / [?lab:T] arguments from a type. *)
let rec strip_labeled_args (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_arrow ((Asttypes.Labelled _ | Asttypes.Optional _), _, rest) ->
      strip_labeled_args rest
  | _ -> ct

let is_unit (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "unit"; _ }, []) -> true
  | _ -> false

(** [(unit, _) result] is the conventional return type for an imperative action
    that may fail ([Slack.invite_to_channel], [Slack.kick_from_channel], ...).
    Treat it like [unit] for naming purposes -- the function is a verb, not a
    constructor of an [`a`]. *)
let is_unit_result (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "result"; _ }, [ ok; _ ]) -> is_unit ok
  | _ -> false

(** Conversion shape: after stripping leading labeled/optional args, the type
    has exactly ONE top-level [Nolabel] arrow ([T1 -> T2]) where [T2] is a
    non-arrow leaf type (so multi-argument functions don't qualify), is not
    [unit] (so writes-into-sink functions like [add_packages_to_map] and
    [respond_to_tool], which return [unit] after several args, don't qualify
    either), and is not [(unit, _) result] (imperative-action-with-error shape).
    The OCaml convention [<dst>_of_<src>] only fits genuine
    single-source/single-result conversions. *)
let is_conversion_type ct =
  match (strip_labeled_args ct).ptyp_desc with
  | Ptyp_arrow (Asttypes.Nolabel, _, ret) -> (
      match ret.ptyp_desc with
      | Ptyp_arrow _ -> false (* second arrow: multi-arg *)
      | _ -> (not (is_unit ret)) && not (is_unit_result ret))
  | _ -> false

(** Pretty-print the source type of a single-arrow conversion. *)
let source_type_pretty ct =
  match (strip_labeled_args ct).ptyp_desc with
  | Ptyp_arrow (Asttypes.Nolabel, src, _) ->
      Fmt.kstr Option.some "%a" Pprintast.core_type src
  | _ -> None

(** Source type-name of a single-arrow conversion, when one exists. Returns
    [None] for variable, tuple, arrow, or otherwise structurally-complex source
    types. *)
let source_type_name ct =
  let rec last = function
    | Longident.Lident s -> s
    | Longident.Ldot (_, s) -> s.txt
    | Longident.Lapply (_, r) -> last r.txt
  in
  match (strip_labeled_args ct).ptyp_desc with
  | Ptyp_arrow (Asttypes.Nolabel, src, _) -> (
      match src.ptyp_desc with
      | Ptyp_constr ({ txt; _ }, _) -> Some (last txt)
      | _ -> None)
  | _ -> None

(** Collect every constructor name reachable from a [core_type]: both the outer
    constructor and any type arguments inside it. For [int list], that is
    [["list"; "int"]]; for [(string * int) list], [["list"; "string"; "int"]].
    The shape of the inferred type Merlin gives for an unannotated body may
    unfold or fold the alias, so both names are accepted. *)
let rec core_type_constrs (ct : Parsetree.core_type) =
  let rec last_id = function
    | Longident.Lident s -> s
    | Longident.Ldot (_, s) -> s.txt
    | Longident.Lapply (_, r) -> last_id r.txt
  in
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt; _ }, args) ->
      last_id txt :: List.concat_map core_type_constrs args
  | Ptyp_tuple cts -> List.concat_map (fun (_, ct) -> core_type_constrs ct) cts
  | Ptyp_alias (inner, _) -> core_type_constrs inner
  | _ -> []

(** [t_aliases outline] is the set of constructor names reachable from any
    [type t = ...] manifest in [outline]. Merlin parses the manifest and exposes
    it via [Outline.parsed_type]; if that returns [None], the [.cmt] / [.cmti]
    for the file isn't built (or merlin can't see it). *)
let t_aliases (outline : Outline.t) =
  List.concat_map
    (fun (item : Outline.item) ->
      if item.kind = Outline.Type && item.name = "t" then
        match Outline.parsed_type item with
        | Some ct -> core_type_constrs ct
        | None -> []
      else [])
    (Outline.flatten outline)

(** A [Ptyp_constr] whose argument list contains a type variable, e.g.
    ['a list], ['a option], ['a Hashtbl.t]. These cases stay flagged ([to_<X>]
    on a polymorphic container still isn't t-sourced), but the diagnostic omits
    the [<X>_of_<head>] suggestion because it would hide the polymorphic
    parameter and read worse than the original. *)
let has_polymorphic_arg (ct : Parsetree.core_type) =
  let rec is_var (ct : Parsetree.core_type) =
    match ct.ptyp_desc with
    | Ptyp_var _ -> true
    | Ptyp_alias (inner, _) -> is_var inner
    | _ -> false
  in
  match ct.ptyp_desc with
  | Ptyp_constr (_, args) -> List.exists is_var args
  | _ -> false

(** [to_<X>] is legitimate when the source is [t] or one of [t]'s aliases. Only
    flag when the source is a {b named} constructor different from [t] and not
    aliased to it. Polymorphic sources (['a]) and structural ones (polymorphic
    variants, tuples, function types) are accepted: they're the inferred shape
    of an [.ml] body that the [.mli] constrains to [t -> ...]. *)
let is_t_sourced ~aliases ct =
  match (strip_labeled_args ct).ptyp_desc with
  | Ptyp_arrow (Asttypes.Nolabel, src, _) -> (
      match src.ptyp_desc with
      | Ptyp_constr _ -> (
          match source_type_name ct with
          | None -> true
          | Some n -> n = "t" || List.mem n aliases)
      | _ -> true)
  | _ -> false

(** Suggested rename. For [_to_] (left=src, right=dst): [<dst>_of_<src>] swaps
    the sides. For [_from_] (left=dst, right=src): [<dst>_of_<src>] is just
    [<left>_of_<right>] — same word order, different separator. *)
let suggested_name ~sep (left, right) =
  match sep with
  | "_to_" -> right ^ "_of_" ^ left
  | "_from_" -> left ^ "_of_" ^ right
  | _ -> assert false

let try_pattern ~sep name =
  match split_separator_pattern ~sep name with
  | Some pair -> Some (suggested_name ~sep pair)
  | None -> None

(** Module-local type [t] is implicit context. Names like [foo_of_t] and
    [t_of_foo] mention it redundantly and should collapse to the shorter
    [to_foo] / [of_foo] forms — the stdlib convention for module-internal
    conversions ([List.to_seq], [Bytes.to_string], [String.of_seq]). Only fires
    when the [t] half is a literal single-character word. *)
let try_t_pattern name =
  match Astring.String.cuts ~sep:"_of_" name with
  | [ "t"; right ]
    when right <> ""
         && (not (String.contains right '_'))
         && not (right.[0] >= '0' && right.[0] <= '9') ->
      Some ("of_" ^ right)
  | [ left; "t" ]
    when left <> ""
         && (not (String.contains left '_'))
         && not (left.[0] >= '0' && left.[0] <= '9') ->
      Some ("to_" ^ left)
  | _ -> None

let find_pattern name =
  match try_pattern ~sep:"_to_" name with
  | Some _ as r -> r
  | None -> (
      match try_pattern ~sep:"_from_" name with
      | Some _ as r -> r
      | None -> try_t_pattern name)

(** A [to_<X>] prefix is legitimate only when the source is the module's [t]
    type ([List.to_seq], [Buffer.to_seq], [Bytes.to_string]). If the name
    matches but the type's first non-labelled argument is not [t], the function
    is masquerading: it should be [<X>_of_<src>] instead. *)
let try_to_prefix_pattern name =
  if String.length name <= 3 || not (String.starts_with ~prefix:"to_" name) then
    None
  else
    let rest = String.sub name 3 (String.length name - 3) in
    if rest = "" || String.contains rest '_' then None
    else if rest.[0] >= '0' && rest.[0] <= '9' then None
    else Some rest

(* Sub-checks return [Some issue] when the function should be flagged. They
   take everything resolved already (parsed type, location), keeping each
   check shallow. *)

let sep_or_t_issue ~loc ~name ~ct =
  match find_pattern name with
  | Some suggested when is_conversion_type ct ->
      Some
        (Issue.v ~loc
           { function_name = name; suggested; kind = Sep_or_t_pattern })
  | _ -> None

let to_prefix_issue ~loc ~aliases ~name ~ct =
  match try_to_prefix_pattern name with
  | Some dst when is_conversion_type ct && not (is_t_sourced ~aliases ct) ->
      let src_type_name = Option.value (source_type_name ct) ~default:"<src>" in
      let src_type_pretty =
        Option.value (source_type_pretty ct) ~default:src_type_name
      in
      let polymorphic_arg =
        match (strip_labeled_args ct).ptyp_desc with
        | Ptyp_arrow (Asttypes.Nolabel, src, _) -> has_polymorphic_arg src
        | _ -> false
      in
      let suggested = dst ^ "_of_" ^ src_type_name in
      Some
        (Issue.v ~loc
           {
             function_name = name;
             suggested;
             kind =
               To_prefix_non_t
                 { src_type_name; src_type_pretty; polymorphic_arg };
           })
  | _ -> None

(* Names starting with underscore are deliberately marked as unused
   (warning 32). Renaming them yields a still-leading-[_] name, which keeps
   the warning, OR a name without [_] which trips warning 32 again. Either
   way the rename isn't safe — leave these alone. *)
let is_underscore_prefixed name = String.length name > 0 && name.[0] = '_'

let check_item ~filename ~allowed ~aliases (item : Outline.item) =
  let name = item.name in
  if item.kind <> Outline.Value then None
  else if List.mem name allowed then None
  else if is_underscore_prefixed name then None
  else
    match (Outline.location filename item, Outline.parsed_type item) with
    | Some loc, Some ct -> (
        match sep_or_t_issue ~loc ~name ~ct with
        | Some _ as r -> r
        | None -> to_prefix_issue ~loc ~aliases ~name ~ct)
    | _ -> None

let check (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  let allowed = ctx.config.allowed_words in
  let aliases = t_aliases outline_data in
  List.filter_map (check_item ~filename ~allowed ~aliases) outline_data

let pp ppf { function_name; suggested; kind } =
  match kind with
  | Sep_or_t_pattern ->
      Fmt.pf ppf
        "Function '%s' uses a non-canonical conversion-naming form; OCaml \
         convention is '%s' (the [<dst>_of_<src>] form, matching \
         [int_of_string], [string_of_float], ...)."
        function_name suggested
  | To_prefix_non_t { src_type_pretty; polymorphic_arg = true; _ } ->
      Fmt.pf ppf
        "Function '%s' uses [to_<X>] but its source type is '%s', which has a \
         polymorphic parameter. Pick a name that captures what the contents \
         represent (e.g. [<X>_of_entries], [<X>_of_chunks]), or rework the API \
         so the source is the module's [t]."
        function_name src_type_pretty
  | To_prefix_non_t { src_type_pretty; polymorphic_arg = false; _ } ->
      Fmt.pf ppf
        "Function '%s' uses [to_<X>] but its source type is '%s', not [t]. \
         Preferred fix: declare [type t = %s] in this module so the function \
         reads as [t -> X] (the canonical primary-type name, per [List.to_seq] \
         / [Bytes.to_string]). Fallback: rename the function to '%s' \
         ([<dst>_of_<src>] form)."
        function_name src_type_pretty src_type_pretty suggested

let rule =
  Rule.v ~code:"E333" ~title:"Prefer _of_ over _to_ / _from_"
    ~category:Naming_conventions
    ~hint:
      "Standalone conversion functions in OCaml use the [<dst>_of_<src>] form \
       ([int_of_string], [string_of_float], ...) — never [<src>_to_<dst>], \
       [<dst>_from_<src>], [<X>_of_t], or [t_of_<X>]. The convention reads as \
       'an X out of a Y' and matches the stdlib precedent. The [to_<X>] prefix \
       is reserved for conversions whose source is the module's own [t] \
       ([List.to_seq], [Bytes.to_string]); use [<X>_of_<src>] when the source \
       is anything else. The rule runs on [.mli] only -- naming is a \
       public-API concern; private helpers in [.ml] are not flagged. The rule \
       only flags single-arrow functions ([T1 -> T2] with non-unit [T2]), so \
       multi-argument actions ([add_to_set : 'a -> 'a list -> 'a list]) and \
       writes-into-sink functions ([print_to_buffer : Buffer.t -> string -> \
       unit]) are skipped by their type. Add domain-specific exceptions to \
       [allowed_words]."
    ~examples:
      [ Example.bad Examples.E333.bad_ml; Example.good Examples.E333.good_ml ]
    ~pp (File check)
