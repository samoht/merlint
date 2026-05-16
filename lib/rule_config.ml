(** Rule exclusion management with file pattern matching *)

let src =
  Logs.Src.create "merlint.rule_config" ~doc:"Rule exclusion configuration"

module Log = (val Logs.src_log src : Logs.LOG)

type rule_pattern = {
  pattern : string;
  rules : string list;
  config_dir : string;
      (** Directory of the [merlint.toml] this exclusion came from. Patterns are
          matched against the file's path {b relative to this directory},
          mirroring how users write them. *)
}

type t = rule_pattern list

let empty = []
let add pattern exclusions = pattern :: exclusions
let merge a b = a @ b

(** Convert glob pattern to regex pattern *)
let regex_of_glob pattern =
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
    let regex_pattern = regex_of_glob pattern in
    let regex = Re.compile (Re.Perl.re regex_pattern) in
    Re.execp regex file
  with Re.Perl.Parse_error | Re.Perl.Not_supported ->
    (* If pattern compilation fails, fall back to simple string matching *)
    String.starts_with ~prefix:pattern file
    || String.ends_with ~suffix:pattern file

(* The file path the user wrote in [merlint.toml] is relative to that
   config's directory. Strip the [config_dir] prefix from [file] before
   matching so [files = "lib/trace.ml"] in [memtrace/merlint.toml] matches
   any analyzed [memtrace/lib/trace.ml] regardless of cwd. *)
let config_relative_file ~config_dir file =
  if config_dir = "" then file
  else
    let prefix =
      if config_dir.[String.length config_dir - 1] = '/' then config_dir
      else config_dir ^ "/"
    in
    if String.starts_with ~prefix file then
      String.sub file (String.length prefix)
        (String.length file - String.length prefix)
    else file

let should_exclude exclusions ~rule ~file =
  let rule_matches_pattern rule_pattern rule_code =
    if String.contains rule_pattern '*' then
      let pattern_prefix = String.split_on_char '*' rule_pattern |> List.hd in
      String.starts_with ~prefix:pattern_prefix rule_code
    else rule_pattern = rule_code
  in
  List.exists
    (fun pattern ->
      let rel = config_relative_file ~config_dir:pattern.config_dir file in
      let pattern_matches =
        matches_pattern pattern.pattern file
        || matches_pattern pattern.pattern rel
      in
      let rule_matches =
        List.exists
          (fun rule_pattern -> rule_matches_pattern rule_pattern rule)
          pattern.rules
      in
      if pattern_matches && rule_matches then
        Log.debug (fun m ->
            m "Exclusion: file %s matches pattern %s for rule %s" file
              pattern.pattern rule);
      pattern_matches && rule_matches)
    exclusions

let pp ppf exclusions =
  let pp_pattern ppf p =
    Fmt.pf ppf "%s = %a" p.pattern
      Fmt.(list ~sep:(const string ", ") string)
      p.rules
  in
  Fmt.pf ppf "%a" Fmt.(list ~sep:(const string "; ") pp_pattern) exclusions

let equal exclusions1 exclusions2 =
  List.equal
    (fun p1 p2 ->
      p1.pattern = p2.pattern && p1.rules = p2.rules
      && p1.config_dir = p2.config_dir)
    exclusions1 exclusions2
