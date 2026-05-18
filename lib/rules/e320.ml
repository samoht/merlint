open Examples
(** E320: Long Identifier Names *)

type payload = { name : string; kind : string; length : int; max_length : int }
(** Payload for long identifier name *)

let is_test_file filename =
  let module_name =
    Filename.basename filename |> Filename.remove_extension
    |> String.lowercase_ascii
  in
  String.starts_with ~prefix:"test_" module_name
  || String.contains filename '/'
     && String.contains (Filename.dirname filename) '/'
     && List.exists
          (fun part -> part = "test")
          (String.split_on_char '/' filename)

let underscore_count name =
  String.fold_left (fun count c -> if c = '_' then count + 1 else count) 0 name

let issue_of_ref ~max_underscores ~allowed ref_ =
  let name = File_view.Reference.base ref_ in
  let length = underscore_count name in
  if
    length > max_underscores
    && String.length name > 5
    && not (List.mem name allowed)
  then
    Option.map
      (fun loc ->
        Issue.v ~loc
          { name; kind = "identifier"; length; max_length = max_underscores })
      (File_view.Reference.loc ref_)
  else None

let dedupe_issue ~seen ~max_underscores ~allowed ref_ =
  let name = File_view.Reference.base ref_ in
  if Hashtbl.mem seen name then None
  else (
    Hashtbl.add seen name ();
    issue_of_ref ~max_underscores ~allowed ref_)

let check (ctx : Context.file) =
  if is_test_file ctx.filename then []
  else
    let max_underscores = ctx.config.max_underscores_in_name in
    let allowed = ctx.config.allowed_words in
    let view = Context.view ctx in
    let refs =
      File_view.outline_identifiers view
      @ File_view.outline_patterns view
      @ File_view.outline_modules view
      @ File_view.outline_types view
      @ File_view.outline_exceptions view
      @ File_view.outline_variant_definitions view
    in
    (* Dedupe by name: a long identifier used N times in pattern matches or
       applications doesn't deserve N findings — the user only renames it
       once. Keep the first location seen. *)
    let seen = Hashtbl.create 32 in
    List.filter_map (dedupe_issue ~seen ~max_underscores ~allowed) refs

let pp ppf { name; kind = _; length; max_length } =
  Fmt.pf ppf "Identifier '%s' has %d underscores (max %d)" name length
    max_length

let rule =
  Rule.v ~code:"E320" ~title:"Long Identifier Names"
    ~category:Naming_conventions
    ~hint:
      "Avoid using too many underscores in identifier names as they make code \
       harder to read. Consider using more descriptive names or restructuring \
       the code to avoid deeply nested concepts."
    ~examples:[ Example.bad E320.bad_ml; Example.good E320.good_ml ]
    ~pp (File check)
