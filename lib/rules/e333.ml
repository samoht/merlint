(** E333: Prefer [<dst>_of_<src>] over [<src>_to_<dst>] / [<dst>_from_<src>] *)

type payload = { function_name : string; suggested : string }
(** Payload for [_to_]- and [_from_]-style conversion names. *)

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

(** [(_, _) result] is the conventional return type for an imperative action
    that may fail ([Slack.invite_to_channel], [Slack.kick_from_channel], the
    Eio-fronting [pull_from_handle : ... -> unit -> (_, error) result], etc.).
    Stdlib's parser/converter precedent ([int_of_string], [Float.of_string])
    raises on failure or returns [option]; [result] is reserved for I/O, system,
    and network operations -- i.e. verbs, not constructors of an ['a]. Skip
    these to avoid the verb/constructor confusion. *)
let is_result (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr
      ({ txt = Lident "result" | Ldot (_, { txt = "result"; _ }); _ }, [ _; _ ])
    ->
      true
  | _ -> false

(** Conversion shape: after stripping leading labeled/optional args, the type
    has exactly ONE top-level [Nolabel] arrow ([T1 -> T2]) where [T2] is a
    non-arrow leaf type (so multi-argument functions don't qualify), is not
    [unit] (so writes-into-sink functions like [add_packages_to_map] and
    [respond_to_tool], which return [unit] after several args, don't qualify
    either), and is not [(_, _) result] (imperative-action-with-error shape).
    The OCaml convention [<dst>_of_<src>] only fits genuine
    single-source/single-result conversions. *)
let is_conversion_type ct =
  match (strip_labeled_args ct).ptyp_desc with
  | Ptyp_arrow (Asttypes.Nolabel, _, ret) -> (
      match ret.ptyp_desc with
      | Ptyp_arrow _ -> false (* second arrow: multi-arg *)
      | _ -> (not (is_unit ret)) && not (is_result ret))
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

let find_pattern name =
  match try_pattern ~sep:"_to_" name with
  | Some _ as r -> r
  | None -> try_pattern ~sep:"_from_" name

let check (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  let allowed = ctx.config.allowed_words in
  List.filter_map
    (fun (item : Outline.item) ->
      let name = item.name in
      match (item.kind, Outline.location filename item) with
      | Outline.Value, Some loc -> (
          if List.mem name allowed then
            None
            (* Names starting with underscore are deliberately marked as
             unused (warning 32). Renaming them yields a still-leading-_
             name, which keeps the warning, OR a name without _ which
             trips warning 32. Either way the rename isn't safe — leave
             these alone. *)
          else if String.length name > 0 && name.[0] = '_' then None
          else
            match (find_pattern name, Outline.parsed_type item) with
            | Some suggested, Some ct when is_conversion_type ct ->
                Some (Issue.v ~loc { function_name = name; suggested })
            | _ -> None)
      | _ -> None)
    outline_data

let pp ppf { function_name; suggested } =
  Fmt.pf ppf
    "Function '%s' uses the [<src>_to_<dst>] / [<dst>_from_<src>] form; OCaml \
     convention is '%s' (the [<dst>_of_<src>] form, matching [int_of_string], \
     [string_of_float], ...)"
    function_name suggested

let rule =
  Rule.v ~code:"E333" ~title:"Prefer _of_ over _to_ / _from_"
    ~category:Naming_conventions
    ~hint:
      "Standalone conversion functions in OCaml use the [<dst>_of_<src>] form \
       ([int_of_string], [string_of_float], ...) — never [<src>_to_<dst>] or \
       [<dst>_from_<src>]. The convention reads as 'an X out of a Y' and \
       matches the stdlib precedent. The rule only flags single-arrow \
       functions ([T1 -> T2] with non-unit [T2]), so multi-argument actions \
       ([add_to_set : 'a -> 'a list -> 'a list]) and writes-into-sink \
       functions ([print_to_buffer : Buffer.t -> string -> unit]) are skipped \
       by their type. Add domain-specific exceptions to [allowed_words]."
    ~examples:
      [ Example.bad Examples.E333.bad_ml; Example.good Examples.E333.good_ml ]
    ~pp (File check)
