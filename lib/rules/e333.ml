(** E333: Prefer [<dst>_of_<src>] over [<src>_to_<dst>] *)

type payload = { function_name : string; suggested : string }
(** Payload for [_to_]-style conversion names. *)

(** Split [name] at its last [_to_]. Returns [Some (src, dst)] when the name has
    the conversion shape [<src>_to_<dst>] with non-empty halves and the [dst]
    half is a single snake_case word (no further [_to_] / [_of_]). Returns
    [None] otherwise — we only flag canonical conversion names, not action verbs
    like [add_to_set] / [walk_to_root]. *)
let split_to_pattern name =
  let rec find_last_to i acc =
    let pat = "_to_" in
    let len = String.length pat in
    if i + len > String.length name then acc
    else if String.sub name i len = pat then find_last_to (i + 1) (Some i)
    else find_last_to (i + 1) acc
  in
  match find_last_to 0 None with
  | None -> None
  | Some i ->
      let src = String.sub name 0 i in
      let dst = String.sub name (i + 4) (String.length name - i - 4) in
      if src = "" || dst = "" then None
      else if String.contains dst '_' then None
      else Some (src, dst)

(** Action verbs that take [_to_<noun>] without being conversions: [add_to_set],
    [walk_to_root], [print_to_buffer], [layer_write_to_top], [scroll_to_bottom].
    We skip names whose [_to_]'s left half ends in one of these, so the rule
    stays focused on canonical conversion names. *)
let action_verbs =
  [
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
    "drop";
    "dump";
    "emit";
    "export";
    "feed";
    "flow";
    "flush";
    "forward";
    "get";
    "go";
    "import";
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
    "post";
    "print";
    "push";
    "redirect";
    "rename";
    "render";
    "respond";
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
    the [<dst>_of_<src>] form would be wrong. *)
let output_sinks =
  [ "buffer"; "channel"; "chan"; "file"; "formatter"; "writer"; "stream" ]

let words s = String.split_on_char '_' s

(** A name is an action when ANY snake-case word on the [src] side OR the [dst]
    side names a verb. Examples that need this:

    - [add_packages_to_map]: src has [add] (start of src).
    - [layer_write_to_top]: src has [write] (end of src).
    - [repos_to_push]: dst is the gerund [push].

    We also exempt:

    - [test_X_to_Y]: a test function named after the conversion it exercises,
      not itself a conversion.
    - [<X>_to_buffer / writer / channel / ...]: writes into a sink, the
      [<dst>_of_<src>] form doesn't apply when the result is [unit].

    Single-word [src]es ([int], [bytes], ...) never match the verb list, so
    canonical conversions are still flagged. *)
let is_action_name (src, dst) =
  let any_verb ws = List.exists (fun w -> List.mem w action_verbs) ws in
  let starts_with_test s = s = "test" || String.starts_with ~prefix:"test_" s in
  starts_with_test src || List.mem dst output_sinks
  || any_verb (words src)
  || any_verb (words dst)

let suggested_name (src, dst) = dst ^ "_of_" ^ src

let check (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  let allowed = ctx.config.allowed_words in
  List.filter_map
    (fun (item : Outline.item) ->
      let name = item.name in
      match (item.kind, Outline.location filename item) with
      | Outline.Value, Some loc -> (
          if List.mem name allowed then None
          else
            match split_to_pattern name with
            | Some pair when is_action_name pair -> None
            | Some pair ->
                Some
                  (Issue.v ~loc
                     { function_name = name; suggested = suggested_name pair })
            | None -> None)
      | _ -> None)
    outline_data

let pp ppf { function_name; suggested } =
  Fmt.pf ppf
    "Function '%s' uses the [<src>_to_<dst>] form; OCaml convention is '%s' \
     (the [<dst>_of_<src>] form, matching [int_of_string], [string_of_float], \
     ...)"
    function_name suggested

let rule =
  Rule.v ~code:"E333" ~title:"Prefer _of_ over _to_"
    ~category:Naming_conventions
    ~hint:
      "Standalone conversion functions in OCaml use the [<dst>_of_<src>] form \
       ([int_of_string], [string_of_float], ...) — never [<src>_to_<dst>]. The \
       convention reads as 'an X out of a Y' and matches the stdlib precedent. \
       Module-method conversions ([Bytes.to_string], [Bytes.of_string]) are \
       unaffected: the rule only flags identifiers that contain [_to_] inside \
       the name itself, and skips action-verb prefixes ([add_to_set], \
       [walk_to_root], [print_to_buffer], etc.). Add domain-specific \
       exceptions to [allowed_words]."
    ~examples:
      [ Example.bad Examples.E333.bad_ml; Example.good Examples.E333.good_ml ]
    ~pp (File check)
