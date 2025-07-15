(** E310: Value Naming Convention *)

let to_snake_case name =
  let rec convert acc = function
    | [] -> String.concat "_" (List.rev acc)
    | c :: rest when c >= 'A' && c <= 'Z' ->
        if acc = [] then convert [ String.make 1 (Char.lowercase_ascii c) ] rest
        else convert (String.make 1 (Char.lowercase_ascii c) :: acc) rest
    | c :: rest -> (
        let ch = String.make 1 c in
        match acc with
        | [] -> convert [ ch ] rest
        | h :: t -> convert ((h ^ ch) :: t) rest)
  in
  convert [] (String.to_seq name |> List.of_seq)

let check_value_name name =
  let expected = to_snake_case name in
  if name <> expected && name <> String.lowercase_ascii name then Some expected
  else None

(** Check a list of elements for naming issues *)
let check_elements elements check_fn create_issue_fn =
  List.filter_map
    (fun (elt : Ast.elt) ->
      let name_str = Ast.name_to_string elt.name in
      match (check_fn name_str, elt.location) with
      | Some result, Some loc -> Some (create_issue_fn name_str loc result)
      | _ -> None)
    elements

let check ~filename:_ ~outline:_ (typedtree : Typedtree.t) =
  (* Check value names *)
  check_elements typedtree.Typedtree.patterns check_value_name
    (fun name_str loc expected ->
      Issue.Bad_value_naming { value_name = name_str; location = loc; expected })
