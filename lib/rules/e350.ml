(** E350: Boolean Blindness - functions with 2+ boolean parameters *)

type payload = { function_name : string; bool_count : int }

(* A value bound to an expression rather than defined with parameters gets its
   shape from whatever it names -- [let bools = Alcotest.(check bool)] is two
   bools because Alcotest says so. The advice to replace them with a variant
   cannot be taken there, since the signature is not this author's to change,
   so only a value that introduces its own parameters is asked. *)
let defines_its_parameters ctx name =
  match
    List.find_opt
      (fun (value : Function_metrics.value) -> String.equal value.name name)
      (File_view.values (Context.view ctx))
  with
  | Some value -> value.is_function
  | None -> true

let check ctx =
  List.filter_map
    (fun item ->
      let module Item = File_view.Item in
      match (Item.kind item, Item.type_sig item) with
      | Item.Value, Some typ when File_view.Type_view.is_function typ ->
          let bool_count =
            File_view.Type_view.count_unlabelled typ
              ~match_:File_view.Type_view.is_bool
          in
          if bool_count >= 2 && defines_its_parameters ctx (Item.name item) then
            Some
              (Issue.v ~loc:(Item.loc item)
                 { function_name = Item.name item; bool_count })
          else None
      | _ -> None)
    (File_view.items (Context.view ctx))

let pp ppf { function_name; bool_count } =
  Fmt.pf ppf
    "Function '%s' has %d boolean parameters - consider using a variant type \
     or record for clarity"
    function_name bool_count

let rule =
  Rule.v ~code:"E350" ~title:"Boolean Blindness" ~category:Rule.Security_safety
    ~hint:
      "Functions with multiple boolean parameters are hard to use correctly. \
       It's easy to mix up the order of arguments at call sites. Consider \
       using variant types, labeled arguments, or a configuration record \
       instead."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|(* BAD - Boolean blindness *)
let create_widget visible bordered = ...
let w = create_widget true false  (* What does this mean? *)|};
        };
        {
          is_good = true;
          code =
            {|(* GOOD - Explicit variants *)
type visibility = Visible | Hidden
type border = With_border | Without_border
let create_widget ~visibility ~border = ...
let w = create_widget ~visibility:Visible ~border:Without_border|};
        };
      ]
    ~pp (File check)
