(** E305: Module Naming Convention *)

type payload = { module_name : string; expected : string }

(** Check if module name follows Snake_case convention *)
let is_snake_case_module name =
  (* Must start with uppercase *)
  String.length name > 0
  && Char.uppercase_ascii name.[0] = name.[0]
  &&
  (* Rest should be lowercase or underscores *)
  String.for_all
    (fun ch -> Char.lowercase_ascii ch = ch || ch = '_')
    (String.sub name 1 (String.length name - 1))

let check (ctx : Context.file) =
  let ast_data = Context.dump ctx in

  (* Check modules for naming convention *)
  List.filter_map
    (fun (module_elt : Dump.elt) ->
      let module_name = Dump.name_to_string module_elt.name in
      if not (is_snake_case_module module_name) then
        let expected = Naming.to_capitalized_snake_case module_name in
        match Dump.location module_elt with
        | Some loc -> Some (Issue.v ~loc { module_name; expected })
        | None -> None
      else None)
    ast_data.modules

let pp ppf { module_name; expected } =
  Fmt.pf ppf "Module '%s' should use Snake_case: '%s'" module_name expected

let rule =
  Rule.v ~code:"E305" ~title:"Module Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Module names should use Snake_case (e.g., My_module, User_profile). \
       File names use lowercase_with_underscores which OCaml automatically \
       converts to module names."
    ~examples:
      [ Example.bad Examples.E305.bad_ml; Example.good Examples.E305.good_ml ]
    ~pp (File check)
