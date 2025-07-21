(** Documentation style analysis and validation *)

type style_issue =
  | Missing_period
  | Bad_function_format
  | Redundant_phrase of string
  | Regular_comment_instead_of_doc

let check_function_doc ~name ~doc =
  (* Function docs should follow: [function_name args] description. *)
  let issues = ref [] in

  (* Check for [name ...] format *)
  let pattern =
    Re.compile
      (Re.seq [ Re.str "["; Re.str name; Re.alt [ Re.space; Re.str "]" ] ])
  in
  let has_bracket_format = Re.execp pattern doc in

  if not has_bracket_format then issues := Bad_function_format :: !issues;

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if
    String.starts_with ~prefix:"this function" lower
    || String.starts_with ~prefix:"this method" lower
  then issues := Redundant_phrase "This function" :: !issues;

  (* Check ends with period *)
  let trimmed = String.trim doc in
  if String.length trimmed > 0 && not (String.ends_with ~suffix:"." trimmed)
  then issues := Missing_period :: !issues;

  !issues

let check_type_doc ~doc =
  (* Type docs should be brief and end with period *)
  let issues = ref [] in

  (* Check ends with period *)
  let trimmed = String.trim doc in
  if String.length trimmed > 0 && not (String.ends_with ~suffix:"." trimmed)
  then issues := Missing_period :: !issues;

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if String.starts_with ~prefix:"this type" lower then
    issues := Redundant_phrase "This type" :: !issues;

  !issues

let check_value_doc ~name:_ ~doc =
  (* Non-function values should have simple descriptions ending with period *)
  let issues = ref [] in

  (* Check ends with period *)
  let trimmed = String.trim doc in
  if String.length trimmed > 0 && not (String.ends_with ~suffix:"." trimmed)
  then issues := Missing_period :: !issues;

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if
    String.starts_with ~prefix:"this value" lower
    || String.starts_with ~prefix:"this variable" lower
  then issues := Redundant_phrase "This value" :: !issues;

  !issues

let pp_style_issue ppf = function
  | Missing_period -> Fmt.string ppf "should end with a period"
  | Bad_function_format ->
      Fmt.string ppf "should use '[function_name args] description.' format"
  | Redundant_phrase phrase -> Fmt.pf ppf "avoid redundant phrase '%s'" phrase
  | Regular_comment_instead_of_doc ->
      Fmt.string ppf "use doc comment (** ... *) instead of regular comment"
