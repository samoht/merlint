(** E210: Avoid X__Y Module Access - Use X.Y Instead *)

type payload = { module_path : string; suggested_path : string }

let special_identifiers =
  [
    "__LOC__";
    "__FILE__";
    "__LINE__";
    "__MODULE__";
    "__POS__";
    "__POS_OF__";
    "__LINE_OF__";
    "__MODULE_OF__";
    "__LOC_OF__";
    "__FUNCTION__";
  ]

let bad_pattern =
  Re.compile (Re.seq [ Re.str "__"; Re.alt [ Re.alnum; Re.char '_' ] ])

let is_special_identifier name =
  let parts = String.split_on_char '.' name in
  List.exists (fun part -> List.mem part special_identifiers) parts

let should_check name base =
  String.contains name '_'
  && (not (String.starts_with ~prefix:"Dune__exe" name))
  && (not (is_special_identifier name))
  && not (String.starts_with ~prefix:"__" base)

let clean_original name =
  if String.contains name '.' then
    match String.split_on_char '.' name with
    | lib :: rest when (not (Re.execp bad_pattern lib)) && List.length rest > 0
      ->
        String.concat "." rest
    | _ -> name
  else name

let clean_suggested original =
  let parts = String.split_on_char '.' original in
  let convert part =
    match String.split_on_char '_' part with
    | [ _ ] -> [ part ]
    | raw_parts ->
        let non_empty = List.filter (fun s -> s <> "") raw_parts in
        non_empty
  in
  let rec dedupe_adjacent = function
    | a :: b :: rest when a = b -> dedupe_adjacent (b :: rest)
    | a :: rest -> a :: dedupe_adjacent rest
    | [] -> []
  in
  parts |> List.concat_map convert |> dedupe_adjacent |> String.concat "."

let line_at content line =
  let lines = String.split_on_char '\n' content in
  List.nth_opt lines (line - 1)

let source_contains_bad_path content loc =
  match line_at content loc.Location.start.line with
  | None -> true
  | Some line ->
      let start_col = max 0 loc.start.col in
      let end_col =
        if loc.end_.line = loc.start.line then
          min (String.length line) loc.end_.col
        else String.length line
      in
      if start_col >= String.length line || end_col <= start_col then true
      else
        let source = String.sub line start_col (end_col - start_col) in
        Re.execp bad_pattern source

let issue_of_identifier content ref_ =
  let name = File_view.Name.to_string (File_view.Reference.name ref_) in
  let base = File_view.Reference.base ref_ in
  if should_check name base && Re.execp bad_pattern name then
    match File_view.Reference.loc ref_ with
    | None -> None
    | Some loc when not (source_contains_bad_path content loc) -> None
    | Some loc ->
        let module_path = clean_original name in
        let suggested_path = clean_suggested module_path in
        Some (Issue.v ~loc { module_path; suggested_path })
  else None

let check (ctx : Context.file) =
  let view = Context.view ctx in
  let content = Context.content ctx in
  File_view.outline_identifiers view @ File_view.outline_modules view
  |> List.filter_map (issue_of_identifier content)

let pp ppf { module_path; suggested_path } =
  Fmt.pf ppf "Use '%s' instead of '%s' - avoid double underscore module access"
    suggested_path module_path

let rule =
  Rule.v ~code:"E210" ~title:"Avoid X__Y Module Access"
    ~category:Style_modernization
    ~hint:
      "Avoid using double underscore module access like 'Module__Submodule'. \
       Use dot notation 'Module.Submodule' instead. Double underscore notation \
       is internal to the OCaml module system and should not be used in \
       application code."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let result = Merlint__Location.v ~file:"test.ml"
                   ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:10|};
        };
        {
          is_good = true;
          code =
            {|let result = Merlint.Location.v ~file:"test.ml"
                   ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:10|};
        };
      ]
    ~pp (File check)
