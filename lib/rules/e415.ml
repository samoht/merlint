open Examples
(** E415: Missing Pretty Printer *)

type payload = { type_name : string; missing_functions : string list }

(** Check if a type has deriving show attribute in the content *)
let has_deriving_show content line_num =
  (* Merlin's outline doesn't include PPX-generated functions, so we need to
     check the source for [@@deriving show] which generates pp automatically. 
     This is a workaround for a Merlin limitation. *)
  try
    let lines = String.split_on_char '\n' content in
    (* Look at a few lines around the type declaration *)
    let start_idx = max 0 (line_num - 1) in
    let end_idx = min (List.length lines) (line_num + 3) in
    let context_lines =
      let rec collect idx acc =
        if idx >= end_idx then acc
        else try collect (idx + 1) (List.nth lines idx :: acc) with _ -> acc
      in
      List.rev (collect start_idx [])
    in
    let context = String.concat " " context_lines in
    (* Simple substring search for deriving show *)
    let rec contains_substring str sub =
      if String.length sub > String.length str then false
      else if String.sub str 0 (String.length sub) = sub then true
      else if String.length str <= 1 then false
      else contains_substring (String.sub str 1 (String.length str - 1)) sub
    in
    contains_substring context "deriving show"
    || contains_substring context "deriving yojson, show"
    || contains_substring context "deriving show,"
  with _ -> false

let check (ctx : Context.file) =
  (* Only check .mli files *)
  if not (String.ends_with ~suffix:".mli" ctx.filename) then []
  else
    let outline = Lazy.force ctx.outline in
    let content = Lazy.force ctx.content in

    (* Find type 't' in the outline *)
    let type_t =
      List.find_opt
        (fun (item : Outline.item) -> item.name = "t" && item.kind = Type)
        outline
    in

    match type_t with
    | None -> [] (* No type t, nothing to check *)
    | Some t_item ->
        (* Get line number for the type *)
        let line_num =
          match t_item.range with Some r -> r.start.line | None -> 1
        in

        (* Check if pp function exists in the outline *)
        let has_pp =
          List.exists
            (fun (item : Outline.item) -> item.name = "pp" && item.kind = Value)
            outline
        in

        (* Check for deriving show *)
        let has_deriving = has_deriving_show content line_num in

        if has_pp || has_deriving then []
        else
          let loc =
            Location.create ~file:ctx.filename ~start_line:line_num ~start_col:0
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
