(** Rule exclusion management with file pattern matching *)

type rule_pattern = { pattern : string; rules : string list }
type t = rule_pattern list

let empty = []
let add pattern exclusions = pattern :: exclusions

(** Convert glob pattern to regex pattern *)
let glob_to_regex pattern =
  let rec convert acc = function
    | [] -> List.rev acc
    | '*' :: '*' :: '/' :: rest ->
        (* ** matches any number of directories *)
        convert ('/' :: '*' :: '.' :: acc) rest
    | '*' :: '*' :: rest ->
        (* ** at the end matches everything *)
        convert ('*' :: '.' :: acc) rest
    | '*' :: rest ->
        (* * matches anything except / *)
        (* Building in reverse order, so [^/]* becomes *]/^[ *)
        convert ('*' :: ']' :: '/' :: '^' :: '[' :: acc) rest
    | '?' :: rest ->
        (* ? matches any single character except / *)
        convert (']' :: '/' :: '^' :: '[' :: acc) rest
    | '.' :: rest ->
        (* Escape dots *)
        convert ('.' :: '\\' :: acc) rest
    | '[' :: rest ->
        (* Escape brackets *)
        convert ('[' :: '\\' :: acc) rest
    | ']' :: rest ->
        (* Escape brackets *)
        convert (']' :: '\\' :: acc) rest
    | c :: rest -> convert (c :: acc) rest
  in
  let chars = List.init (String.length pattern) (String.get pattern) in
  let regex_chars = convert [] chars in
  let regex_str = String.concat "" (List.map (String.make 1) regex_chars) in
  "^" ^ regex_str ^ "$"

(** Check if a file path matches a glob pattern *)
let matches_pattern pattern file =
  try
    let regex_pattern = glob_to_regex pattern in
    let regex = Re.compile (Re.Perl.re regex_pattern) in
    Re.execp regex file
  with Re.Perl.Parse_error | Re.Perl.Not_supported ->
    (* If pattern compilation fails, fall back to simple string matching *)
    String.starts_with ~prefix:pattern file
    || String.ends_with ~suffix:pattern file

let should_exclude exclusions ~rule ~file =
  List.exists
    (fun pattern ->
      matches_pattern pattern.pattern file && List.mem rule pattern.rules)
    exclusions

let parse_exclusion_line line =
  let line = String.trim line in
  if String.length line = 0 || String.get line 0 = '#' then None
  else
    match String.split_on_char '=' line with
    | [ pattern_str; rules_str ] ->
        let pattern = String.trim pattern_str in
        let rules_str = String.trim rules_str in
        let rules =
          rules_str |> String.split_on_char ',' |> List.map String.trim
          |> List.filter (fun s -> String.length s > 0)
        in
        if String.length pattern > 0 && List.length rules > 0 then
          Some { pattern; rules }
        else None
    | _ -> None

let pp ppf exclusions =
  let pp_pattern ppf p =
    Fmt.pf ppf "%s = %a" p.pattern
      Fmt.(list ~sep:(const string ", ") string)
      p.rules
  in
  Fmt.pf ppf "%a" Fmt.(list ~sep:(const string "; ") pp_pattern) exclusions

let equal exclusions1 exclusions2 =
  List.equal
    (fun p1 p2 -> p1.pattern = p2.pattern && p1.rules = p2.rules)
    exclusions1 exclusions2
