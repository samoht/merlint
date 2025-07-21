(** Documentation style analysis and validation *)

type style_issue =
  | Missing_period
  | Bad_function_format
  | Redundant_phrase of string
  | Regular_comment_instead_of_doc

let check_function_doc ~name ~doc =
  (* Function docs should follow: [function_name args] description. *)
  let issues = ref [] in

  (* Check for [name ...] format *)
  let pattern =
    Re.compile
      (Re.seq [ Re.str "["; Re.str name; Re.alt [ Re.space; Re.str "]" ] ])
  in
  let has_bracket_format = Re.execp pattern doc in

  if not has_bracket_format then issues := Bad_function_format :: !issues;

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if
    String.starts_with ~prefix:"this function" lower
    || String.starts_with ~prefix:"this method" lower
  then issues := Redundant_phrase "This function" :: !issues;

  (* Check ends with period *)
  let trimmed = String.trim doc in
  if String.length trimmed > 0 && not (String.ends_with ~suffix:"." trimmed)
  then issues := Missing_period :: !issues;

  !issues

let check_type_doc ~doc =
  (* Type docs should be brief and end with period *)
  let issues = ref [] in

  (* Check ends with period *)
  let trimmed = String.trim doc in
  if String.length trimmed > 0 && not (String.ends_with ~suffix:"." trimmed)
  then issues := Missing_period :: !issues;

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if String.starts_with ~prefix:"this type" lower then
    issues := Redundant_phrase "This type" :: !issues;

  !issues

let check_value_doc ~name:_ ~doc =
  (* Non-function values should have simple descriptions ending with period *)
  let issues = ref [] in

  (* Check ends with period *)
  let trimmed = String.trim doc in
  if String.length trimmed > 0 && not (String.ends_with ~suffix:"." trimmed)
  then issues := Missing_period :: !issues;

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if
    String.starts_with ~prefix:"this value" lower
    || String.starts_with ~prefix:"this variable" lower
  then issues := Redundant_phrase "This value" :: !issues;

  !issues

let pp_style_issue ppf = function
  | Missing_period -> Fmt.string ppf "should end with a period"
  | Bad_function_format ->
      Fmt.string ppf "should use '[function_name args] description.' format"
  | Redundant_phrase phrase -> Fmt.pf ppf "avoid redundant phrase '%s'" phrase
  | Regular_comment_instead_of_doc ->
      Fmt.string ppf "use doc comment (** ... *) instead of regular comment"

type doc_comment = {
  value_name : string;
  signature : string;
  doc : string;
  doc_line : int;
  val_line : int;
}

let is_function_signature signature =
  (* Check if the signature contains -> indicating a function *)
  Re.execp (Re.compile (Re.str "->")) signature

(** Extract the doc attribute from an attribute list *)
let find_doc_attribute attrs =
  let open Ppxlib in
  List.find_opt
    (fun attr ->
      match attr.attr_name.txt with "ocaml.doc" -> true | _ -> false)
    attrs
  |> Option.map (fun attr ->
         match attr.attr_payload with
         | PStr
             [
               {
                 pstr_desc =
                   Pstr_eval
                     ( {
                         pexp_desc = Pexp_constant (Pconst_string (doc, _, _));
                         _;
                       },
                       _ );
                 _;
               };
             ] ->
             String.trim doc
         | _ -> "")

(** Extract the location info from a Ppxlib location *)
let extract_location (loc : Ppxlib.location) =
  let start_line = loc.loc_start.pos_lnum in
  let end_line = loc.loc_end.pos_lnum in
  (start_line, end_line)

(** Get the string representation of a core type *)
let rec core_type_to_string (typ : Ppxlib.core_type) =
  let open Ppxlib in
  match typ.ptyp_desc with
  | Ptyp_var name -> "'" ^ name
  | Ptyp_constr ({ txt = Lident name; _ }, []) -> name
  | Ptyp_constr ({ txt = Ldot (_, name); _ }, []) -> name
  | Ptyp_arrow (_, t1, t2) ->
      let arg_str = core_type_to_string t1 in
      let ret_str = core_type_to_string t2 in
      arg_str ^ " -> " ^ ret_str
  | Ptyp_tuple types ->
      let type_strs = List.map core_type_to_string types in
      String.concat " * " type_strs
  | _ -> "<complex type>"

(** Extract documentation comments using ppxlib *)
let extract_doc_comments content =
  try
    let open Ppxlib in
    (* Parse as a signature (interface file) *)
    let lexbuf = Lexing.from_string content in
    let signature = Parse.interface lexbuf in

    (* We need to also check for regular comments in the original content
       since ppxlib doesn't preserve them in the AST *)
    let lines = String.split_on_char '\n' content in
    let regular_comments = ref [] in

    (* Find regular comments that precede value declarations *)
    List.iteri
      (fun i line ->
        let trimmed = String.trim line in
        if
          Re.execp (Re.compile (Re.str "(* ")) trimmed
          && Re.execp (Re.compile (Re.str " *)")) trimmed
          && not (String.starts_with ~prefix:"(**" trimmed)
        then
          if
            (* Found a regular comment, check if next line is a val *)
            i + 1 < List.length lines
          then
            let next_line = String.trim (List.nth lines (i + 1)) in
            if String.starts_with ~prefix:"val " next_line then
              regular_comments := (i + 2, "BAD_COMMENT") :: !regular_comments)
      lines;

    (* Extract doc comments from signature items *)
    let doc_comments = ref [] in
    let last_floating_doc = ref None in

    List.iter
      (fun (sig_item : signature_item) ->
        match sig_item.psig_desc with
        | Psig_attribute attr when attr.attr_name.txt = "ocaml.doc" -> (
            (* Floating doc comment *)
            match attr.attr_payload with
            | PStr
                [
                  {
                    pstr_desc =
                      Pstr_eval
                        ( {
                            pexp_desc = Pexp_constant (Pconst_string (doc, _, _));
                            _;
                          },
                          _ );
                    _;
                  };
                ] ->
                let doc_line, _ = extract_location attr.attr_loc in
                last_floating_doc := Some (doc, doc_line)
            | _ -> ())
        | Psig_value vd ->
            (* Value declaration *)
            let value_name = vd.pval_name.txt in
            let signature = core_type_to_string vd.pval_type in
            let val_line, _ = extract_location vd.pval_loc in

            (* Check if this value has a regular comment *)
            let has_regular_comment =
              List.exists (fun (line, _) -> line = val_line) !regular_comments
            in

            if has_regular_comment then
              (* Found regular comment instead of doc comment *)
              doc_comments :=
                {
                  value_name;
                  signature;
                  doc = "BAD_COMMENT";
                  doc_line = val_line - 1;
                  val_line;
                }
                :: !doc_comments
            else
              (* First check for attached doc attribute *)
              let attached_doc = find_doc_attribute vd.pval_attributes in

              (* Use attached doc if available, otherwise use floating doc *)
              let doc_info =
                match attached_doc with
                | Some doc when doc <> "" -> Some (doc, val_line)
                | _ -> !last_floating_doc
              in

              (* Clear floating doc after use *)
              last_floating_doc := None;

              (* Always add the value, even without doc *)
              let doc, doc_line =
                match doc_info with
                | Some (d, l) -> (d, l)
                | None -> ("", val_line)
              in

              doc_comments :=
                { value_name; signature; doc; doc_line; val_line }
                :: !doc_comments
        | _ ->
            (* Any other item clears the floating doc *)
            last_floating_doc := None)
      signature;

    List.rev !doc_comments
  with Parsing.Parse_error | Failure _ ->
    (* If ppxlib parsing fails, return empty list *)
    []
