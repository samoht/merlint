open Examples
(** E415: Missing Standard Functions *)

type payload = { type_name : string; missing_functions : string list }

let standard_functions = [ "pp" ]

let extract_type_declarations content =
  let lines = String.split_on_char '\n' content in
  let rec scan idx acc =
    if idx >= List.length lines then List.rev acc
    else
      let line = String.trim (List.nth lines idx) in
      if String.starts_with ~prefix:"type " line then
        (* Extract type name *)
        let type_name =
          try
            let start = 5 in
            (* after "type " *)
            let rec find_end i =
              if i >= String.length line then i
              else
                let c = String.get line i in
                if c = ' ' || c = '=' || c = '<' then i else find_end (i + 1)
            in
            let end_idx = find_end start in
            String.sub line start (end_idx - start)
          with _ -> ""
        in
        if type_name = "t" then
          (* Only check for 'type t' *)
          scan (idx + 1) ((type_name, idx + 1) :: acc)
        else scan (idx + 1) acc
      else scan (idx + 1) acc
  in
  scan 0 []

let extract_function_declarations content =
  let lines = String.split_on_char '\n' content in
  let rec scan idx acc =
    if idx >= List.length lines then acc
    else
      let line = String.trim (List.nth lines idx) in
      if String.starts_with ~prefix:"val " line then
        (* Extract function name *)
        let func_name =
          try
            let start = 4 in
            (* after "val " *)
            let rec find_end i =
              if i >= String.length line then i
              else
                let c = String.get line i in
                if c = ' ' || c = ':' then i else find_end (i + 1)
            in
            let end_idx = find_end start in
            String.sub line start (end_idx - start)
          with _ -> ""
        in
        if func_name <> "" then scan (idx + 1) (func_name :: acc)
        else scan (idx + 1) acc
      else scan (idx + 1) acc
  in
  scan 0 []

let check (ctx : Context.file) =
  (* Only check .mli files *)
  if not (String.ends_with ~suffix:".mli" ctx.filename) then []
  else
    let content = Lazy.force ctx.content in
    let type_decls = extract_type_declarations content in
    let func_decls = extract_function_declarations content in

    (* For each type, check if standard functions exist *)
    List.filter_map
      (fun (type_name, line_num) ->
        let missing =
          List.filter
            (fun std_func ->
              (* Look for function with various naming patterns:
                 - equal (for generic types)
                 - type_name_equal (e.g., user_equal)
                 - Type_name.equal (e.g., User.equal) *)
              let patterns =
                [
                  std_func;
                  (* Direct match like "equal" *)
                  type_name ^ "_" ^ std_func;
                  (* e.g., "user_equal" *)
                  String.capitalize_ascii type_name ^ "." ^ std_func;
                  (* e.g., "User.equal" *)
                ]
              in
              not
                (List.exists
                   (fun pattern -> List.mem pattern func_decls)
                   patterns))
            standard_functions
        in
        if missing <> [] then
          let loc =
            Location.create ~file:ctx.filename ~start_line:line_num ~start_col:0
              ~end_line:line_num ~end_col:0
          in
          Some (Issue.v ~loc { type_name; missing_functions = missing })
        else None)
      type_decls

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
