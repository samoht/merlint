(** E305: Module Naming Convention *)

type payload = { module_name : string; expected : string }

(** Check if module name follows Snake_case convention *)
let is_snake_case_module name =
  (* Must start with uppercase *)
  String.length name > 0
  && Char.uppercase_ascii name.[0] = name.[0]
  &&
  (* Allow all-uppercase names (for acronyms like HTML, JSON, ONF, CNF) *)
  (String.for_all (fun ch -> Char.uppercase_ascii ch = ch || ch = '_') name
  ||
  (* Or rest should be lowercase or underscores (Snake_case) *)
  String.for_all
    (fun ch -> Char.lowercase_ascii ch = ch || ch = '_')
    (String.sub name 1 (String.length name - 1)))

let check (ctx : Context.file) =
  let allowed = ctx.config.allowed_words in
  match ctx.project_index with
  | Some idx
    when Project_index.is_generated_source_file idx
           (Context.fpath_of_path (Context.file_path ctx)) ->
      []
  | _ ->
      File_view.outline_module_definitions (Context.view ctx)
      |> List.filter_map (fun module_ref ->
          let module_name = File_view.Reference.base module_ref in
          if List.mem module_name allowed then None
          else if not (is_snake_case_module module_name) then
            let expected = Naming.to_capitalized_snake_case module_name in
            if expected <> module_name then
              Option.map
                (fun loc -> Issue.v ~loc { module_name; expected })
                (File_view.Reference.loc module_ref)
            else None
          else None)

let pp ppf { module_name; expected } =
  Fmt.pf ppf "Module '%s' should use Snake_case: '%s'" module_name expected

let rule =
  Rule.v ~code:"E305" ~title:"Module Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Module names should use Snake_case (e.g., My_module, User_profile) or \
       all-uppercase for acronyms (e.g., HTML, JSON, ONF). File names use \
       lowercase_with_underscores which OCaml automatically converts to module \
       names."
    ~examples:
      [ Example.bad Examples.E305.bad_ml; Example.good Examples.E305.good_ml ]
    ~pp (File check)
