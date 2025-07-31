(** Dump module - handles all AST text dump parsing functionality *)

let src = Logs.Src.create "merlint.dump" ~doc:"AST dump parsing"

module Log = (val Logs.src_log src : Logs.LOG)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type t = {
  modules : elt list;  (** Module names *)
  types : elt list;  (** Type declarations *)
  exceptions : elt list;  (** Exception declarations *)
  variants : elt list;  (** Variant constructors *)
  identifiers : elt list;  (** Value identifiers (usage) *)
  patterns : elt list;  (** Pattern variables *)
  values : elt list;  (** Value bindings (definitions) *)
}
(** Extracted names and identifiers from the AST dump *)

(** What kind of AST dump we're parsing *)
type what = Parsetree | Typedtree

exception Parse_error of string
(** Parse error exception *)

exception Type_error
(** Type error exception - raised when typedtree contains type errors *)

exception Wrong_ast_type
(** Wrong AST type exception - raised when parsing Typedtree but found Parsetree
    nodes *)

(** Convert a structured name to a string *)
let name_to_string (n : name) =
  match n.prefix with
  | [] -> n.base
  | prefix -> String.concat "." prefix ^ "." ^ n.base

(** Token kinds *)
type token_kind =
  | Word of string
  | Location of
      Location.t (* Parsed location like (file.ml[1,0+0]..file.ml[1,0+31]) *)
  | Module (* Tstr_module / Pstr_module *)
  | Type (* Tstr_type / Pstr_type *)
  | Type_declaration (* type_declaration *)
  | Value (* Tstr_value / Pstr_value *)
  | Exception (* Tstr_exception / Pstr_exception *)
  | Variant (* Ttype_variant / Ptype_variant *)
  | Ident (* Texp_ident / Pexp_ident *)
  | Construct (* Texp_construct / Pexp_construct *)
  | Pattern (* Tpat_var / Ppat_var *)
  | Attribute (* Tstr_attribute / Pstr_attribute *)
  | LParen
  | RParen
  | LBracket
  | RBracket

type token = { kind : token_kind; loc : Location.t option }
(** Token representation *)

(** Empty accumulator for name extraction *)
let empty_acc =
  {
    modules = [];
    types = [];
    exceptions = [];
    variants = [];
    identifiers = [];
    patterns = [];
    values = [];
    (* All value bindings including functions *)
  }

(** Helper regex components for location parsing *)
let filename = Re.rep1 (Re.compl [ Re.char '[' ])

let number = Re.rep1 Re.digit

let location_part =
  Re.seq
    [
      Re.str "[";
      Re.group number;
      Re.str ",";
      number;
      Re.str "+";
      Re.group number;
      Re.str "]";
    ]

let loc_regex =
  Re.compile
    (Re.seq
       [
         Re.str "(";
         Re.group filename;
         location_part;
         Re.str "..";
         filename;
         location_part;
         Re.str ")";
       ])

let parse_location str =
  try
    let m = Re.exec loc_regex str in
    let file = Re.Group.get m 1 in
    let start_line = int_of_string (Re.Group.get m 2) in
    let start_col = int_of_string (Re.Group.get m 3) in
    let end_line = int_of_string (Re.Group.get m 4) in
    let end_col = int_of_string (Re.Group.get m 5) in
    Some (Location.v ~file ~start_line ~start_col ~end_line ~end_col)
  with Not_found -> None

(** Lookup table for AST node kinds *)
let ast_node_map =
  [
    (* Typedtree nodes *)
    ("Tstr_module", Module);
    ("Tstr_type", Type);
    ("Tstr_value", Value);
    ("Tstr_exception", Exception);
    ("Ttype_variant", Variant);
    ("Texp_ident", Ident);
    ("Texp_construct", Construct);
    ("Tpat_var", Pattern);
    ("Tstr_attribute", Attribute);
    (* Parsetree nodes *)
    ("Pstr_module", Module);
    ("Pstr_type", Type);
    ("Pstr_value", Value);
    ("Pstr_exception", Exception);
    ("Ptype_variant", Variant);
    ("Pexp_ident", Ident);
    ("Pexp_construct", Construct);
    ("Ppat_var", Pattern);
    ("Pstr_attribute", Attribute);
    (* Context-independent *)
    ("type_declaration", Type_declaration);
  ]

(** Get AST node token kind if word is a recognized AST node in the given
    context *)
let ast_node_kind word =
  (* Since we handle both Typedtree and Parsetree nodes in both contexts,
     we can use a single lookup table *)
  List.assoc_opt word ast_node_map

(** Classify a word as either an AST node or just a word *)
let classify_word word =
  match ast_node_kind word with Some k -> k | None -> Word word

(** Check if we're at the start of a location pattern *)
let is_location_start text pos =
  pos < String.length text
  && text.[pos] = '('
  &&
  try
    (* Look for pattern like (file.ml[... *)
    let rec check i =
      if i >= String.length text then false
      else if text.[i] = '[' then true
      else if text.[i] = ' ' || text.[i] = '\n' then false
      else check (i + 1)
    in
    check (pos + 1)
  with Invalid_argument _ -> false

(** Parse a complete location token *)
let parse_location_token text start_pos =
  let rec find_end pos paren_count =
    if pos >= String.length text then pos
    else
      match text.[pos] with
      | '(' -> find_end (pos + 1) (paren_count + 1)
      | ')' ->
          if paren_count = 1 then pos + 1
          else find_end (pos + 1) (paren_count - 1)
      | _ -> find_end (pos + 1) paren_count
  in
  let end_pos = find_end start_pos 0 in
  let loc_str = String.sub text start_pos (end_pos - start_pos) in
  (parse_location loc_str, end_pos)

(* Phase 1: Lexer - Convert raw text to tokens *)

(** Process end of text *)
let process_end_of_text acc current =
  if current = "" then List.rev acc
  else
    let kind = classify_word current in
    List.rev ({ kind; loc = None } :: acc)

(** Process location token *)
let process_location_token acc text pos what_context tokenize =
  let loc_opt, new_pos = parse_location_token text pos in
  match loc_opt with
  | Some loc ->
      tokenize
        ({ kind = Location loc; loc = None } :: acc)
        "" new_pos what_context
  | None ->
      (* Failed to parse as location, treat as regular paren *)
      tokenize ({ kind = LParen; loc = None } :: acc) "" (pos + 1) what_context

(** Process whitespace character *)
let process_whitespace acc current pos what_context tokenize =
  if current = "" then tokenize acc current (pos + 1) what_context
  else
    let kind = classify_word current in
    tokenize ({ kind; loc = None } :: acc) "" (pos + 1) what_context

(** Process bracket character *)
let process_bracket bracket acc current pos what_context tokenize =
  let bracket_kind =
    match bracket with
    | '(' -> LParen
    | ')' -> RParen
    | '[' -> LBracket
    | ']' -> RBracket
    | _ -> assert false
  in
  let acc' =
    if current = "" then acc
    else
      let kind = classify_word current in
      { kind; loc = None } :: acc
  in
  tokenize
    ({ kind = bracket_kind; loc = None } :: acc')
    "" (pos + 1) what_context

let lex_text what text : token list =
  (* Tokenizer that recognizes AST nodes based on current what context *)
  let rec tokenize acc current pos what_context =
    if pos >= String.length text then process_end_of_text acc current
    else if current = "" && is_location_start text pos then
      process_location_token acc text pos what_context tokenize
    else
      let ch = text.[pos] in
      match ch with
      | ' ' | '\n' | '\t' ->
          process_whitespace acc current pos what_context tokenize
      | ('(' | ')' | '[' | ']') as bracket ->
          process_bracket bracket acc current pos what_context tokenize
      | _ -> tokenize acc (current ^ String.make 1 ch) (pos + 1) what_context
  in
  tokenize [] "" 0 what

(** Parse structured name from string like "Str.regexp" or "Stdlib!.Obj.magic"
*)
let parse_name str =
  (* Remove quotes if present *)
  let str =
    let len = String.length str in
    if len >= 2 && str.[0] = '"' && str.[len - 1] = '"' then
      String.sub str 1 (len - 2)
    else str
  in
  (* Remove unique suffix like /123 if present *)
  let str =
    match String.index_opt str '/' with
    | Some i -> String.sub str 0 i
    | None -> str
  in
  (* Remove ! markers from stdlib names *)
  let str = String.map (fun c -> if c = '!' then ' ' else c) str in
  (* Split by . to get components, filtering out empty parts *)
  let parts =
    String.split_on_char '.' str
    |> List.map String.trim
    |> List.filter (fun s -> s <> "")
  in
  match List.rev parts with
  | [] -> { prefix = []; base = "" }
  | base :: rev_modules -> { prefix = List.rev rev_modules; base }

(* Phase 2: Parser - Convert tokens into structured data *)

(* Skip attribute contents - they can contain mixed AST nodes *)
let rec skip_attribute depth = function
  | [] -> []
  | { kind = LBracket; _ } :: rest -> skip_attribute (depth + 1) rest
  | { kind = RBracket; _ } :: rest ->
      if depth <= 1 then rest else skip_attribute (depth - 1) rest
  | _ :: rest -> skip_attribute depth rest

(* Helper for parsing named items *)
let parse_named_item tokens =
  match tokens with
  | { kind = Word name_with_id; _ } :: rest
    when String.contains name_with_id '/' ->
      Some (parse_name name_with_id, rest)
  | _ -> None

(* Parse variant list - can have multiple variants in sequence *)
let parse_variant_list acc location tokens continue_parse =
  (* Helper to update variants accumulator *)
  let add_variant acc' name current_loc =
    { acc' with variants = { name; location = current_loc } :: acc'.variants }
  in

  (* Parse multiple variants until we hit something else *)
  let rec collect_variants acc' current_loc = function
    | [] -> continue_parse acc' location []
    | { kind; _ } :: rest -> (
        match kind with
        (* Update location if we see a location token *)
        | Location loc -> collect_variants acc' (Some loc) rest
        (* Variant name *)
        | Word content when String.contains content '/' ->
            let name = parse_name content in
            let new_acc = add_variant acc' name current_loc in
            collect_variants new_acc current_loc rest
        (* Keep going through brackets and other tokens *)
        | LBracket | RBracket | Word _ -> collect_variants acc' current_loc rest
        (* Stop when we hit another AST node *)
        | _ -> continue_parse acc' location ({ kind; loc = None } :: rest))
  in
  collect_variants acc location tokens

(** Parse token stream into structured AST *)
let parse_tokens tokens =
  (* Helper to dispatch to specific parsers *)
  let rec dispatch_parser acc location rest = function
    | Module -> parse_module acc location rest
    | Type -> parse_type acc location rest
    | Type_declaration -> parse_type_declaration acc location rest
    | Variant -> parse_variants acc location rest
    | Ident -> parse_ident acc location rest
    | Pattern -> parse_pattern acc location rest
    | Value -> parse_value acc location rest
    | Construct -> parse_construct acc location rest
    | Attribute -> parse_attribute acc location rest
    | _ -> parse acc location rest
  and parse acc location = function
    | [] -> acc
    | { kind = Location loc; _ } :: rest ->
        (* Direct location token *)
        parse acc (Some loc) rest
    | { kind = Word content; _ } :: rest
      when String.ends_with ~suffix:"_item" content
           || content = "structure_item" ->
        (* structure_item or similar - location already parsed if it was there *)
        parse acc location rest
    | { kind; _ } :: rest ->
        (* Found an AST node token or other *)
        dispatch_parser acc location rest kind
  and parse_module acc location tokens =
    match parse_named_item tokens with
    | Some (name, rest) ->
        let new_acc =
          { acc with modules = { name; location } :: acc.modules }
        in
        parse new_acc location rest
    | None -> parse acc location tokens
  and parse_type acc location rest =
    (* Just continue parsing, types are handled by TypeDeclaration *)
    parse acc location rest
  and parse_type_declaration acc location tokens =
    match parse_named_item tokens with
    | Some (name, rest) ->
        let new_acc = { acc with types = { name; location } :: acc.types } in
        parse new_acc location rest
    | None -> parse acc location tokens
  and parse_variants acc location tokens =
    parse_variant_list acc location tokens parse
  and parse_ident acc location tokens =
    match tokens with
    | { kind = Word content; _ } :: rest ->
        let name = parse_name content in
        let new_acc =
          { acc with identifiers = { name; location } :: acc.identifiers }
        in
        parse new_acc location rest
    | rest -> parse acc location rest
  and parse_pattern acc location tokens =
    match tokens with
    | { kind = Word content; _ } :: rest ->
        let name = parse_name content in
        let new_acc =
          { acc with patterns = { name; location } :: acc.patterns }
        in
        parse new_acc location rest
    | rest -> parse acc location rest
  and parse_value acc location rest =
    (* Just continue parsing, values might be handled differently *)
    parse acc location rest
  and parse_construct acc location tokens =
    match tokens with
    | { kind = Word content; _ } :: rest ->
        let name = parse_name content in
        let new_acc =
          { acc with variants = { name; location } :: acc.variants }
        in
        parse new_acc location rest
    | rest -> parse acc location rest
  and parse_attribute acc location tokens =
    (* Attributes are typically followed by [ ... ] *)
    match tokens with
    | { kind = Word _; _ } :: { kind = LBracket; _ } :: rest ->
        parse acc location (skip_attribute 1 rest)
    | _ -> parse acc location tokens
  in

  parse empty_acc None tokens

(** Parse AST text with specific what *)
let text what input =
  (* Phase 1: Lex the text into tokens *)
  let tokens = lex_text what input in
  (* Phase 2: Parse tokens into structured data *)
  parse_tokens tokens

(** Parse parsetree text dump into AST structure *)
let parsetree input = text Parsetree input

(** Parse typedtree text dump into AST structure *)
let typedtree input =
  (* Try Typedtree first, fall back to Parsetree if there are type errors *)
  try
    let result = text Typedtree input in
    (* Check for type errors *)
    let has_type_error =
      List.exists (fun id -> id.name.base = "*type-error*") result.identifiers
    in
    if has_type_error then raise Type_error else result
  with
  | Type_error ->
      (* Type errors in the code - try with Parsetree *)
      Log.debug (fun m -> m "Type errors detected, falling back to Parsetree");
      text Parsetree input
  | Wrong_ast_type ->
      (* Wrong AST type - Parsetree nodes in what should be Typedtree *)
      Log.debug (fun m ->
          m "Wrong AST type detected, falling back to Parsetree");
      text Parsetree input

(** Utility functions for working with dump data *)

let iter_identifiers_with_location dump_data f =
  List.iter
    (fun (id : elt) ->
      match id.location with Some loc -> f id loc | None -> ())
    dump_data.identifiers

let location (elt : elt) = elt.location

let check_identifier_pattern identifiers pattern_match issue_constructor =
  List.filter_map
    (fun (id : elt) ->
      match id.location with
      | Some loc ->
          let name = id.name in
          if pattern_match name then Some (issue_constructor ~loc) else None
      | None -> None)
    identifiers

let check_module_usage identifiers module_name issue_constructor =
  check_identifier_pattern identifiers
    (fun name ->
      match name.prefix with
      | [ "Stdlib"; m ] when m = module_name -> true
      | [ m ] when m = module_name -> true
      | _ -> false)
    issue_constructor

let check_function_usage identifiers module_name function_name issue_constructor
    =
  check_identifier_pattern identifiers
    (fun name ->
      match (name.prefix, name.base) with
      | [ "Stdlib"; m ], base when m = module_name && base = function_name ->
          true
      | [ m ], base when m = module_name && base = function_name -> true
      | _ -> false)
    issue_constructor

let check_elements elements check_fn create_issue_fn =
  List.filter_map
    (fun (elt : elt) ->
      let name_str = name_to_string elt.name in
      match (check_fn name_str, elt.location) with
      | Some result, Some loc -> Some (create_issue_fn name_str loc result)
      | _ -> None)
    elements

(** Standard functions for type t *)

let equal_name n1 n2 = n1.prefix = n2.prefix && n1.base = n2.base
let equal_elt e1 e2 = equal_name e1.name e2.name && e1.location = e2.location

let equal t1 t2 =
  List.equal equal_elt t1.modules t2.modules
  && List.equal equal_elt t1.types t2.types
  && List.equal equal_elt t1.exceptions t2.exceptions
  && List.equal equal_elt t1.variants t2.variants
  && List.equal equal_elt t1.identifiers t2.identifiers
  && List.equal equal_elt t1.patterns t2.patterns
  && List.equal equal_elt t1.values t2.values

let compare_name n1 n2 =
  match compare n1.prefix n2.prefix with 0 -> compare n1.base n2.base | n -> n

let compare_elt e1 e2 =
  match compare_name e1.name e2.name with
  | 0 -> compare e1.location e2.location
  | n -> n

let compare t1 t2 =
  match List.compare compare_elt t1.modules t2.modules with
  | 0 -> (
      match List.compare compare_elt t1.types t2.types with
      | 0 -> (
          match List.compare compare_elt t1.exceptions t2.exceptions with
          | 0 -> (
              match List.compare compare_elt t1.variants t2.variants with
              | 0 -> (
                  match
                    List.compare compare_elt t1.identifiers t2.identifiers
                  with
                  | 0 -> (
                      match
                        List.compare compare_elt t1.patterns t2.patterns
                      with
                      | 0 -> List.compare compare_elt t1.values t2.values
                      | n -> n)
                  | n -> n)
              | n -> n)
          | n -> n)
      | n -> n)
  | n -> n

let pp_name ppf name = Fmt.pf ppf "%s" (name_to_string name)

let pp_elt ppf elt =
  match elt.location with
  | Some loc -> Fmt.pf ppf "%a at %a" pp_name elt.name Location.pp loc
  | None -> pp_name ppf elt.name

let pp_elt_list name ppf elts =
  if elts <> [] then
    Fmt.pf ppf "@[<v2>%s (%d):@,%a@]@." name (List.length elts)
      (Fmt.list ~sep:Fmt.cut pp_elt)
      elts

let pp ppf t =
  Fmt.pf ppf "@[<v>";
  pp_elt_list "Modules" ppf t.modules;
  pp_elt_list "Types" ppf t.types;
  pp_elt_list "Exceptions" ppf t.exceptions;
  pp_elt_list "Variants" ppf t.variants;
  pp_elt_list "Identifiers" ppf t.identifiers;
  pp_elt_list "Patterns" ppf t.patterns;
  pp_elt_list "Values" ppf t.values;
  Fmt.pf ppf "@]"
