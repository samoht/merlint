(** Documentation style analysis and validation *)

type style_issue =
  | Missing_period
  | Bad_function_format
  | Bad_value_format
  | Bad_operator_format
  | Wrong_arg_count of { expected : int; found : int }
  | Redundant_phrase of string
  | Regular_comment_instead_of_doc

(** Count required and total arguments in a signature string. e.g., "?foo:int ->
    string -> int -> bool" has 2 required, 3 total. Returns (required_count,
    total_count). Ignores arrows inside parentheses (function-typed arguments).
*)
let count_args signature =
  (* Count top-level arrows only, ignoring those inside parentheses *)
  let rec scan_args acc_total acc_optional depth i optional_in_arg =
    if i >= String.length signature then (acc_optional, acc_total)
    else
      match signature.[i] with
      | '(' ->
          scan_args acc_total acc_optional (depth + 1) (i + 1) optional_in_arg
      | ')' ->
          scan_args acc_total acc_optional
            (max 0 (depth - 1))
            (i + 1) optional_in_arg
      | '-'
        when depth = 0
             && i + 1 < String.length signature
             && signature.[i + 1] = '>' ->
          (* Found a top-level arrow, this completes an argument *)
          let new_optional =
            if optional_in_arg then acc_optional + 1 else acc_optional
          in
          scan_args (acc_total + 1) new_optional depth (i + 2) false
      | '?' when depth = 0 ->
          scan_args acc_total acc_optional depth (i + 1) true
      | _ -> scan_args acc_total acc_optional depth (i + 1) optional_in_arg
  in
  let optional_count, total_count = scan_args 0 0 0 0 false in
  let required_count = max 0 (total_count - optional_count) in
  (required_count, total_count)

(** Count arguments in a doc pattern [name arg1 arg2 ...] *)
let count_doc_args doc_content =
  (* doc_content is the content inside [...], e.g., "name arg1 arg2" *)
  let parts =
    String.split_on_char ' ' doc_content
    |> List.filter (fun s -> String.trim s <> "")
  in
  (* First part is the name, rest are args *)
  max 0 (List.length parts - 1)

let check_bracket_format ~name ~signature ~is_operator ~doc issues =
  let bracket_pattern =
    Re.compile
      (Re.seq
         [
           Re.str "[";
           Re.group (Re.rep1 (Re.diff Re.any (Re.char ']')));
           Re.str "]";
         ])
  in
  match Re.exec_opt bracket_pattern doc with
  | Some groups ->
      let bracket_content = Re.Group.get groups 1 in
      let parts =
        String.split_on_char ' ' bracket_content
        |> List.filter (fun s -> String.trim s <> "")
      in
      let doc_name = if List.length parts > 0 then List.hd parts else "" in
      (* If using bracket format, the name should match *)
      if is_operator then begin
        (* For operators, check infix notation [x op y] *)
        let infix_pattern =
          Re.compile
            (Re.seq
               [ Re.str "["; Re.rep1 Re.alnum; Re.space; Re.str name; Re.space ])
        in
        if not (Re.execp infix_pattern doc) then
          issues := Bad_operator_format :: !issues
      end
      else begin
        (* For regular functions, check that doc name matches function name *)
        if doc_name <> name then issues := Bad_function_format :: !issues;
        (* Check argument count - [name] alone is always valid,
           but if args are provided they should be within valid range *)
        let found_args = count_doc_args bracket_content in
        if found_args > 0 then begin
          let min_args, max_args = count_args signature in
          if found_args < min_args then
            issues :=
              Wrong_arg_count { expected = min_args; found = found_args }
              :: !issues
          else if found_args > max_args then
            issues :=
              Wrong_arg_count { expected = max_args; found = found_args }
              :: !issues
        end
      end
  | None -> ()

let check_ends_with_period ~doc issues =
  let trimmed = String.trim doc in
  let has_list_markers =
    Re.execp (Re.compile (Re.str "- ")) doc
    || Re.execp (Re.compile (Re.str "* ")) doc
    || Re.execp (Re.compile (Re.str "+ ")) doc
  in
  if
    String.length trimmed > 0
    && (not (String.ends_with ~suffix:"." trimmed))
    && (not (String.ends_with ~suffix:"]}" trimmed))
    && not (has_list_markers && String.ends_with ~suffix:")" trimmed)
  then issues := Missing_period :: !issues

let check_function_doc ~name ~signature ~doc =
  (* If doc uses [x ...] format, verify x matches the function name
     and has the right number of arguments. Otherwise, accept any doc format. *)
  let issues = ref [] in

  (* Check if this is an operator *)
  let operator_keywords =
    [ "mod"; "land"; "lor"; "lxor"; "lsl"; "lsr"; "asr"; "or"; "and" ]
  in
  let is_operator =
    List.mem name operator_keywords
    || String.length name > 0
       && not
            (match name.[0] with
            | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
            | _ -> false)
  in

  (* Extract the content inside [...] if present *)
  check_bracket_format ~name ~signature ~is_operator ~doc issues;

  (* No bracket format - that's fine, accept as valid *)

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if
    String.starts_with ~prefix:"this function" lower
    || String.starts_with ~prefix:"this method" lower
  then issues := Redundant_phrase "This function" :: !issues;

  (* Check ends with period (but not if it ends with a code block ]} or if it's a list ending with ) *)
  check_ends_with_period ~doc issues;

  !issues

let check_type_doc ~doc =
  (* Type docs should be brief and end with period *)
  let issues = ref [] in

  (* Check ends with period (but not if it ends with a code block ]} or if it's a list ending with ) *)
  let trimmed = String.trim doc in
  let has_list_markers =
    Re.execp (Re.compile (Re.str "- ")) doc
    || Re.execp (Re.compile (Re.str "* ")) doc
    || Re.execp (Re.compile (Re.str "+ ")) doc
  in
  if
    String.length trimmed > 0
    && (not (String.ends_with ~suffix:"." trimmed))
    && (not (String.ends_with ~suffix:"]}" trimmed))
    && not (has_list_markers && String.ends_with ~suffix:")" trimmed)
  then issues := Missing_period :: !issues;

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if String.starts_with ~prefix:"this type" lower then
    issues := Redundant_phrase "This type" :: !issues;

  !issues

let check_value_doc ~name ~doc =
  (* If doc uses [x] format, verify x matches the value name.
     Otherwise, accept any doc format. *)
  let issues = ref [] in

  (* Extract the name used in [name] format if present *)
  let bracket_pattern =
    Re.compile
      (Re.seq
         [
           Re.str "[";
           Re.group (Re.rep1 (Re.diff Re.any (Re.set " ]")));
           Re.str "]";
         ])
  in
  (match Re.exec_opt bracket_pattern doc with
  | Some groups ->
      let doc_name = Re.Group.get groups 1 in
      (* If using bracket format, the name should match *)
      if doc_name <> name then issues := Bad_value_format :: !issues
  | None -> ());

  (* No bracket format - that's fine, accept as valid *)

  (* Check ends with period (but not if it ends with a code block ]} or if it's a list ending with ) *)
  let trimmed = String.trim doc in
  let has_list_markers =
    Re.execp (Re.compile (Re.str "- ")) doc
    || Re.execp (Re.compile (Re.str "* ")) doc
    || Re.execp (Re.compile (Re.str "+ ")) doc
  in
  if
    String.length trimmed > 0
    && (not (String.ends_with ~suffix:"." trimmed))
    && (not (String.ends_with ~suffix:"]}" trimmed))
    && not (has_list_markers && String.ends_with ~suffix:")" trimmed)
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
      Fmt.string ppf "uses [name] format but name doesn't match"
  | Bad_value_format ->
      Fmt.string ppf "uses [name] format but name doesn't match"
  | Bad_operator_format ->
      Fmt.string ppf "should use '[x op y] description.' format for operators"
  | Wrong_arg_count { expected; found } ->
      Fmt.pf ppf "has %d args in doc but function takes %d required args" found
        expected
  | Redundant_phrase phrase -> Fmt.pf ppf "avoid redundant phrase '%s'" phrase
  | Regular_comment_instead_of_doc ->
      Fmt.string ppf "use doc comment (** ... *) instead of regular comment"

let equal_style_issue = ( = )

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
let doc_attribute (attrs : Parsetree.attributes) =
  List.find_opt
    (fun (attr : Parsetree.attribute) ->
      match attr.attr_name.txt with "ocaml.doc" -> true | _ -> false)
    attrs
  |> Option.map (fun (attr : Parsetree.attribute) ->
      match attr.attr_payload with
      | PStr
          [
            {
              pstr_desc =
                Pstr_eval
                  ( {
                      pexp_desc =
                        Pexp_constant
                          { pconst_desc = Pconst_string (doc, _, _); _ };
                      _;
                    },
                    _ );
              _;
            };
          ] ->
          String.trim doc
      | _ -> "")

(** Extract the location info from a compiler-libs location *)
let extract_location_info loc_start loc_end =
  (* Access Lexing.position fields directly *)
  let start_line = loc_start.Lexing.pos_lnum in
  let end_line = loc_end.Lexing.pos_lnum in
  (start_line, end_line)

(** Get the string representation of a core type. The [~wrap_arrows] parameter
    controls whether arrow types should be wrapped in parentheses (used for
    function-typed arguments). *)
let rec core_type_to_string ?(wrap_arrows = false) (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_var name -> "'" ^ name
  | Ptyp_constr ({ txt = Lident name; _ }, []) -> name
  | Ptyp_constr ({ txt = Ldot (_, name); _ }, []) -> name.txt
  | Ptyp_arrow (label, t1, t2) ->
      (* When processing arguments, wrap arrow types in parentheses *)
      let label_prefix = match label with Optional _ -> "?" | _ -> "" in
      let arg_str = core_type_to_string ~wrap_arrows:true t1 in
      let ret_str = core_type_to_string t2 in
      let result = label_prefix ^ arg_str ^ " -> " ^ ret_str in
      if wrap_arrows then "(" ^ result ^ ")" else result
  | Ptyp_tuple types ->
      let type_strs = List.map (fun (_, t) -> core_type_to_string t) types in
      String.concat " * " type_strs
  | _ -> "<complex type>"

(** Check if a line is a regular comment immediately before a val declaration.
*)
let is_comment_before_val lines i trimmed =
  Re.execp (Re.compile (Re.str "(* ")) trimmed
  && Re.execp (Re.compile (Re.str " *)")) trimmed
  && (not (String.starts_with ~prefix:"(**" trimmed))
  && i + 1 < List.length lines
  && String.starts_with ~prefix:"val " (String.trim (List.nth lines (i + 1)))

(** Find regular comments that precede value declarations *)
let regular_comments lines =
  let regular_comments = ref [] in
  List.iteri
    (fun i line ->
      let trimmed = String.trim line in
      if is_comment_before_val lines i trimmed then
        regular_comments := (i + 2, "BAD_COMMENT") :: !regular_comments)
    lines;
  !regular_comments

(** Process a value declaration and extract its documentation *)
let process_value_declaration (vd : Parsetree.value_description)
    ~regular_comments ~last_floating_doc =
  let value_name = vd.pval_name.txt in
  let signature = core_type_to_string vd.pval_type in
  let val_line, _ =
    extract_location_info vd.pval_loc.loc_start vd.pval_loc.loc_end
  in

  (* Check if this value has a regular comment *)
  let has_regular_comment =
    List.exists (fun (line, _) -> line = val_line) regular_comments
  in

  if has_regular_comment then
    (* Found regular comment instead of doc comment *)
    {
      value_name;
      signature;
      doc = "BAD_COMMENT";
      doc_line = val_line - 1;
      val_line;
    }
  else
    (* First check for attached doc attribute *)
    let attached_doc = doc_attribute vd.pval_attributes in

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
      match doc_info with Some (d, l) -> (d, l) | None -> ("", val_line)
    in

    { value_name; signature; doc; doc_line; val_line }

(** Extract documentation comments using compiler-libs *)
let extract_doc_comments content =
  try
    (* Parse as a signature (interface file) *)
    let lexbuf = Lexing.from_string content in
    let signature = Parse.interface lexbuf in

    (* We need to also check for regular comments in the original content
       since the parser doesn't preserve them in the AST *)
    let lines = String.split_on_char '\n' content in
    let regular_comments = regular_comments lines in

    (* Extract doc comments from signature items *)
    let doc_comments = ref [] in
    let last_floating_doc = ref None in

    List.iter
      (fun (sig_item : Parsetree.signature_item) ->
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
                            pexp_desc =
                              Pexp_constant
                                { pconst_desc = Pconst_string (doc, _, _); _ };
                            _;
                          },
                          _ );
                    _;
                  };
                ] ->
                let doc_line, _ =
                  extract_location_info attr.attr_loc.loc_start
                    attr.attr_loc.loc_end
                in
                last_floating_doc := Some (doc, doc_line)
            | _ -> ())
        | Psig_value vd ->
            let comment =
              process_value_declaration vd ~regular_comments ~last_floating_doc
            in
            doc_comments := comment :: !doc_comments
        | _ ->
            (* Any other item clears the floating doc *)
            last_floating_doc := None)
      signature;

    List.rev !doc_comments
  with Parsing.Parse_error | Failure _ ->
    (* If parsing fails, return empty list *)
    []
