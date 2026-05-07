(** E333: Prefer [<dst>_of_<src>] over [<src>_to_<dst>] / [<dst>_from_<src>] *)

type payload = { function_name : string; suggested : string }
(** Payload for [_to_]- and [_from_]-style conversion names. *)

(** Split [name] at its last occurrence of [sep]. Returns [Some (left, right)]
    when the name has the conversion shape [<left><sep><right>] with non-empty
    halves and the [right] half is a single snake_case word (no further [_to_] /
    [_of_] / [_from_]). Returns [None] otherwise — we only flag canonical
    conversion names, not action verbs like [add_to_set] / [walk_to_root] /
    [recover_from_error]. *)
let split_separator_pattern ~sep name =
  let plen = String.length sep in
  let rec count_occurrences i n =
    if i + plen > String.length name then n
    else if String.sub name i plen = sep then count_occurrences (i + 1) (n + 1)
    else count_occurrences (i + 1) n
  in
  let rec find_last_sep i acc =
    if i + plen > String.length name then acc
    else if String.sub name i plen = sep then find_last_sep (i + 1) (Some i)
    else find_last_sep (i + 1) acc
  in
  (* Multiple occurrences suggest a conjunctive name like
     [to_first_and_to_last] — not a single conversion. Skip. *)
  if count_occurrences 0 0 <> 1 then None
  else
    match find_last_sep 0 None with
    | None -> None
    | Some i ->
        let left = String.sub name 0 i in
        let right =
          String.sub name (i + plen) (String.length name - i - plen)
        in
        if left = "" || right = "" then None
        else if String.contains right '_' then
          None
          (* [left] starts with the bare separator (e.g. [to_first_and] for
             [_to_]) — likely a phrase-style name composed around an existing
             [to_X] / [from_X] function, not a conversion. *)
        else
          let bare = String.sub sep 1 (plen - 2) ^ "_" in
          if String.starts_with ~prefix:bare left then
            None
            (* [right] starts with a digit (e.g. [image_to_2d]) — swapping
             would yield [2d_of_image], not a valid OCaml identifier. *)
          else if right.[0] >= '0' && right.[0] <= '9' then None
          else Some (left, right)

(** Action verbs that take [_to_<noun>] / [_from_<noun>] without being
    conversions: [add_to_set], [walk_to_root], [print_to_buffer],
    [read_from_buffer], [recover_from_error]. We skip names whose split's sides
    contain one of these. *)
let action_verbs =
  [
    "accept";
    "add";
    "append";
    "attach";
    "belong";
    "bind";
    "broadcast";
    "compare";
    "connect";
    "convert";
    "copy";
    "derive";
    "descend";
    "drop";
    "dump";
    "emit";
    "export";
    "extract";
    "feed";
    "fetch";
    "flow";
    "flush";
    "forward";
    "get";
    "go";
    "import";
    "inherit";
    "jump";
    "lead";
    "link";
    "load";
    "log";
    "match";
    "move";
    "navigate";
    "open";
    "point";
    "pop";
    "post";
    "print";
    "pull";
    "push";
    "read";
    "receive";
    "recover";
    "redirect";
    "rename";
    "render";
    "respond";
    "restore";
    "route";
    "save";
    "scroll";
    "send";
    "serialise";
    "serialize";
    "set";
    "skip";
    "spill";
    "step";
    "stick";
    "stream";
    "submit";
    "subscribe";
    "switch";
    "take";
    "talk";
    "through";
    "transfer";
    "transition";
    "transmit";
    "travel";
    "walk";
    "wire";
    "write";
  ]

(** Sinks that the function is writing INTO rather than converting INTO.
    [value_to_buffer] writes a [value] to a [Buffer]; the result is [unit], so
    the [<dst>_of_<src>] form would be wrong. Only relevant for [_to_] (the sink
    sits on the right). *)
let output_sinks =
  [ "buffer"; "channel"; "chan"; "file"; "formatter"; "writer"; "stream" ]

let words s = String.split_on_char '_' s

(** A name is an action when ANY snake-case word on either side names a verb.
    Examples that need this:

    - [add_packages_to_map]: left has [add] (start).
    - [layer_write_to_top]: left has [write] (end).
    - [repos_to_push]: right is the gerund [push].
    - [read_from_buffer]: left is the verb [read].
    - [recover_from_error]: left is the verb [recover].

    We also exempt:

    - [test_X_to_Y] / [test_X_from_Y]: a test function named after the
      conversion it exercises, not itself a conversion.
    - [<X>_to_buffer / writer / channel / ...]: writes into a sink, the
      [<dst>_of_<src>] form doesn't apply when the result is [unit]. Only
      checked for [_to_] (sinks sit on the right of [_to_], not [_from_];
      reading [value_from_buffer] IS a conversion).

    Single-word noun sides ([int], [bytes], ...) never match the verb list, so
    canonical conversions are still flagged. *)
let is_action_name ~sep (left, right) =
  let any_verb ws = List.exists (fun w -> List.mem w action_verbs) ws in
  let starts_with_test s = s = "test" || String.starts_with ~prefix:"test_" s in
  let sink_check = sep = "_to_" && List.mem right output_sinks in
  starts_with_test left || sink_check
  || any_verb (words left)
  || any_verb (words right)

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
  | Some pair when not (is_action_name ~sep pair) ->
      Some (suggested_name ~sep pair)
  | _ -> None

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
          if
            (* Names starting with underscore are deliberately marked as
             unused (warning 32). Renaming them yields a still-leading-_
             name, which keeps the warning, OR a name without _ which
             trips warning 32. Either way the rename isn't safe — leave
             these alone. *)
            List.mem name allowed
          then None
          else if String.length name > 0 && name.[0] = '_' then None
          else
            match find_pattern name with
            | Some suggested ->
                Some (Issue.v ~loc { function_name = name; suggested })
            | None -> None)
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
       matches the stdlib precedent. Module-method conversions \
       ([Bytes.to_string], [Bytes.of_string]) are unaffected: the rule only \
       flags identifiers that contain [_to_] / [_from_] inside the name \
       itself, and skips action-verb prefixes ([add_to_set], [walk_to_root], \
       [print_to_buffer], [read_from_buffer], [recover_from_error], etc.). Add \
       domain-specific exceptions to [allowed_words]."
    ~examples:
      [ Example.bad Examples.E333.bad_ml; Example.good Examples.E333.good_ml ]
    ~pp (File check)
