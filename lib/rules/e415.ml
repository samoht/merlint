open Examples

(** E415: Missing Pretty Printer *)

type payload = { type_name : string; missing_functions : string list }

let item_named kind name item =
  File_view.Item.kind item = kind && File_view.Item.name item = name

let has_pp items = List.exists (item_named File_view.Item.Value "pp") items

let is_function_type item =
  match File_view.Item.type_sig item with
  | Some typ -> File_view.Type_view.is_function typ
  | None -> false

let is_opaque_type item =
  File_view.Item.children item = []
  && Option.is_none (File_view.Item.type_sig item)

let check_type items t_item =
  if
    has_pp items
    || File_view.Item.derives t_item "show"
    || is_opaque_type t_item || is_function_type t_item
  then []
  else
    let loc = File_view.Item.loc t_item in
    [ Issue.v ~loc { type_name = "t"; missing_functions = [ "pp" ] } ]

let check (ctx : Context.file) =
  if not (File_kind.is_mli (Context.filename ctx)) then []
  else
    let items = File_view.items (Context.view ctx) in
    match List.find_opt (item_named File_view.Item.Type "t") items with
    | None -> []
    | Some t_item -> check_type items t_item

let pp ppf { type_name; missing_functions } =
  Fmt.pf ppf "Type '%s' is missing standard functions: %s" type_name
    (String.concat ", " missing_functions)

let rule =
  Rule.v ~code:"E415" ~title:"Missing Pretty Printer" ~category:Documentation
    ~hint:
      "The main type 't' should implement a pretty-printer function (pp) for \
       better debugging and logging. Unlike equality and comparison which can \
       use polymorphic functions (= and compare), pretty-printing requires a \
       custom implementation to provide meaningful output."
    ~examples:[ Example.bad E415.bad_mli; Example.good E415.good_mli ]
    ~pp (File check)
