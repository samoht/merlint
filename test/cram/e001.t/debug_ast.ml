open Ppxlib

let () =
  let content = In_channel.with_open_text "bad.ml" In_channel.input_all in
  let lexbuf = Lexing.from_string content in
  let structure = Parse.implementation lexbuf in
  List.iter (fun item ->
    match item.pstr_desc with
    | Pstr_value (_, bindings) ->
        List.iter (fun vb ->
          match vb.pvb_pat.ppat_desc with
          | Ppat_var { txt = name; _ } ->
              Printf.printf "Found binding: %s\n" name;
              Printf.printf "Expression kind: ";
              (match vb.pvb_expr.pexp_desc with
              | Pexp_function _ -> Printf.printf "Pexp_function\n"
              | Pexp_ifthenelse _ -> Printf.printf "Pexp_ifthenelse\n"
              | _ -> Printf.printf "Other\n")
          | _ -> ()
        ) bindings
    | _ -> ()
  ) structure
