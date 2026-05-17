open Examples

(** E415: Missing Pretty Printer *)

type payload = { type_name : string; missing_functions : string list }

let nearby_lines content line_num =
  let lines = String.split_on_char '\n' content in
  let start_idx = max 0 (line_num - 1) in
  let end_idx = min (List.length lines) (line_num + 3) in
  lines
  |> List.filteri (fun idx _ -> idx >= start_idx && idx < end_idx)
  |> String.concat " "

(** Check if a type definition is a function type *)
let is_function_type content line_num =
  let context = nearby_lines content line_num in
  let arrow_pattern = Re.compile (Re.str "->") in
  Re.execp arrow_pattern context

(** Check if a type has deriving show attribute in the content *)
let has_deriving_show content line_num =
  (* Merlin's outline doesn't include PPX-generated functions, so we need to
     check the source for [@@deriving show] which generates pp automatically. 
     This is a workaround for a Merlin limitation. *)
  let context = nearby_lines content line_num in
  Astring.String.is_infix ~affix:"deriving show" context
  || Astring.String.is_infix ~affix:"deriving yojson, show" context
  || Astring.String.is_infix ~affix:"deriving show," context

let check (ctx : Context.file) =
  (* Only check .mli files *)
  if not (File_kind.is_mli ctx.filename) then []
  else
    let items = File_view.items (Context.view ctx) in
    let content = Context.content ctx in

    (* Find type 't' in the outline *)
    let type_t =
      List.find_opt
        (fun item ->
          File_view.Item.name item = "t"
          && File_view.Item.kind item = File_view.Item.Type)
        items
    in

    match type_t with
    | None -> [] (* No type t, nothing to check *)
    | Some t_item ->
        (* Get line number for the type *)
        let line_num = (File_view.Item.loc t_item).start.line in

        (* Check if pp function exists in the outline *)
        let has_pp =
          List.exists
            (fun item ->
              File_view.Item.name item = "pp"
              && File_view.Item.kind item = File_view.Item.Value)
            items
        in

        (* Check for deriving show *)
        let has_deriving = has_deriving_show content line_num in

        (* Check if it's a function type - don't require pp for function types *)
        let is_function = is_function_type content line_num in

        if has_pp || has_deriving || is_function then []
        else
          let loc =
            Location.v ~file:ctx.filename ~start_line:line_num ~start_col:0
              ~end_line:line_num ~end_col:0
          in
          [ Issue.v ~loc { type_name = "t"; missing_functions = [ "pp" ] } ]

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
