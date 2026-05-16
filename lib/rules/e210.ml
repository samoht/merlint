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
  Re.replace_string (Re.compile (Re.str "__")) ~by:"." original

let issue_of_identifier ref_ =
  let name = File_view.Name.to_string (File_view.Reference.name ref_) in
  let base = File_view.Reference.base ref_ in
  if should_check name base && Re.execp bad_pattern name then
    let module_path = clean_original name in
    let suggested_path = clean_suggested module_path in
    Option.map
      (fun loc -> Issue.v ~loc { module_path; suggested_path })
      (File_view.Reference.loc ref_)
  else None

let check (ctx : Context.file) =
  let view = Context.view ctx in
  File_view.outline_identifiers view @ File_view.outline_modules view
  |> List.filter_map issue_of_identifier

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
