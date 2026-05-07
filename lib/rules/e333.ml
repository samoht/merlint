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

(** Count [->] occurrences at depth 0 (outside parens/brackets). *)
let count_top_arrows s =
  let n = String.length s in
  let depth = ref 0 in
  let count = ref 0 in
  let i = ref 0 in
  while !i < n do
    (match s.[!i] with
    | '(' | '[' -> incr depth
    | ')' | ']' -> decr depth
    | '-' when !depth = 0 && !i + 1 < n && s.[!i + 1] = '>' ->
        incr count;
        i := !i + 1
    | _ -> ());
    incr i
  done;
  !count

(** If [s] starts with a [~lab:T] or [?lab:T] argument followed by a top-level
    arrow, return the suffix after that arrow. *)
let strip_one_label s =
  let m = String.length s in
  if m = 0 || (s.[0] <> '~' && s.[0] <> '?') then None
  else
    let depth = ref 0 in
    let i = ref 0 in
    let found = ref None in
    while !found = None && !i < m - 1 do
      (match s.[!i] with
      | '(' | '[' -> incr depth
      | ')' | ']' -> decr depth
      | '-' when !depth = 0 && s.[!i + 1] = '>' -> found := Some (!i + 2)
      | _ -> ());
      incr i
    done;
    match !found with
    | Some pos -> Some (String.trim (String.sub s pos (m - pos)))
    | None -> None

let rec strip_leading_labels s =
  match strip_one_label s with Some s' -> strip_leading_labels s' | None -> s

(** Substring after the rightmost top-level arrow, trimmed. *)
let return_type_of s =
  let n = String.length s in
  let depth = ref 0 in
  let last_arrow = ref None in
  let i = ref 0 in
  while !i < n - 1 do
    (match s.[!i] with
    | '(' | '[' -> incr depth
    | ')' | ']' -> decr depth
    | '-' when !depth = 0 && s.[!i + 1] = '>' ->
        last_arrow := Some !i;
        i := !i + 1
    | _ -> ());
    incr i
  done;
  match !last_arrow with
  | Some p -> String.trim (String.sub s (p + 2) (n - p - 2))
  | None -> String.trim s

(** Drop the rightmost path-qualifier of a type expression: ["Bytes.t"] ->
    ["t"], ["int"] -> ["int"]. *)
let strip_module_qual s =
  match String.rindex_opt s '.' with
  | Some i -> String.sub s (i + 1) (String.length s - i - 1)
  | None -> s

(** Conversion shape: after stripping leading labeled/optional args, the type
    has exactly one top-level arrow ([T1 -> T2]) and [T2] is not [unit]. *)
let is_conversion_type type_sig =
  let s = strip_leading_labels (String.trim type_sig) in
  count_top_arrows s = 1
  &&
  let ret = return_type_of s |> strip_module_qual in
  ret <> "unit"

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
            match (find_pattern name, item.type_sig) with
            | Some suggested, Some ty when is_conversion_type ty ->
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
