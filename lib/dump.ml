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

(** Convert a structured name to a string *)
let name_to_string (n : name) =
  match n.prefix with
  | [] -> n.base
  | prefix -> String.concat "." prefix ^ "." ^ n.base

type token = { indent : int; content : string; loc : Location.t option }
(** Phase 1: Token type for lexing *)

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
    Some (Location.create ~file ~start_line ~start_col ~end_line ~end_col)
  with Not_found -> None

(** Parse line indentation - counts leading spaces *)
let parse_indent line =
  let len = String.length line in
  let rec count_spaces i =
    if i < len && line.[i] = ' ' then count_spaces (i + 1) else i
  in
  count_spaces 0

(** Phase 1: Lexer - Convert raw text to tokens *)
let lex_text ?(parse_loc_from_line = true) text : token list =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let len = String.length line in
         if len = 0 then None
         else
           let indent = parse_indent line in
           let trimmed = String.trim line in
           if trimmed = "" then None
           else
             let loc =
               if parse_loc_from_line then parse_location line else None
             in
             Some { indent; content = trimmed; loc })

(** Extract node type from token content *)
let get_node_type content =
  match String.index_opt content ' ' with
  | Some idx -> String.sub content 0 idx
  | None -> content

(** Extract content between quotes (useful for parsing AST dumps) *)
let quoted_string line =
  let quote_regex =
    Re.compile
      (Re.seq
         [
           Re.str "\"";
           Re.group (Re.rep (Re.compl [ Re.char '"' ]));
           Re.str "\"";
         ])
  in
  try
    let m = Re.exec quote_regex line in
    Some (Re.Group.get m 1)
  with Not_found -> None

(** Parse structured name from string like "Str.regexp" or "Stdlib!.Obj.magic"
*)
let parse_name str =
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

(** Normalize node type based on what *)
let normalize_node_type (what : what) (node_type : string) : string =
  (* Special cases that don't follow P/T convention *)
  match node_type with
  | "Param_pat" | "Nolabel" | "Nonrec" | "Rec" | "Optional" | "Labelled"
  | "Some" | "None" | "Const_int" | "Const_string" | "Const_float"
  | "type_declaration" | "attribute" | "structure_item" ->
      node_type
  | _ -> (
      if String.length node_type < 2 then node_type
      else
        let prefix = node_type.[0] in
        match (prefix, what) with
        | 'T', Typedtree | 'P', Parsetree ->
            (* Correct prefix for the what, so we strip it. *)
            String.sub node_type 1 (String.length node_type - 1)
        | 'P', Typedtree ->
            (* This shouldn't happen - raise error *)
            let error_msg =
              Printf.sprintf
                "Found Parsetree node '%s' while parsing for Typedtree."
                node_type
            in
            raise (Parse_error error_msg)
        | 'T', Parsetree ->
            (* This shouldn't happen - raise error *)
            let error_msg =
              Printf.sprintf
                "Found Typedtree node '%s' while parsing for Parsetree."
                node_type
            in
            raise (Parse_error error_msg)
        | _ ->
            (* Not a P or T node, so return it as is *)
            node_type)

(** Determine the parsing mode based on node type *)
let determine_what current_what token node_type =
  if node_type = "Tstr_attribute" then Parsetree
  else if token.indent <= 8 && String.starts_with ~prefix:"T" node_type then
    Typedtree
  else if token.indent <= 8 && String.starts_with ~prefix:"P" node_type then
    Parsetree
  else current_what

(** Check if we're in a variant section *)
let update_variant_section in_variant_section token node_type =
  if node_type = "Ttype_variant" || node_type = "Ptype_variant" then true
  else if token.indent <= 8 && String.starts_with ~prefix:"ptype_" token.content
  then false
  else in_variant_section

(** Try to normalize a node type, falling back to original on error *)
let safe_normalize_node_type what node_type =
  try
    if
      String.starts_with ~prefix:"T" node_type
      || String.starts_with ~prefix:"P" node_type
      || List.mem node_type
           [
             "type_declaration";
             "attribute";
             "structure_item";
             "Param_pat";
             "Nolabel";
             "Nonrec";
             "Rec";
             "Optional";
             "Labelled";
             "Some";
             "None";
             "Const_int";
             "Const_string";
             "Const_float";
           ]
    then normalize_node_type what node_type
    else node_type
  with Parse_error _ -> node_type

(** Extract name from a token based on normalized node type *)
let extract_name_from_token acc location normalized token =
  match normalized with
  | "exp_ident" | "pat_var" -> (
      match quoted_string token.content with
      | Some str ->
          let name = parse_name str in
          if normalized = "exp_ident" then
            { acc with identifiers = { name; location } :: acc.identifiers }
          else { acc with patterns = { name; location } :: acc.patterns }
      | None -> acc)
  | "exp_construct" | "pat_construct" | "pat_variant" -> (
      match quoted_string token.content with
      | Some str ->
          let name = parse_name str in
          { acc with variants = { name; location } :: acc.variants }
      | None -> acc)
  | "type_declaration" -> (
      let parts = String.split_on_char ' ' token.content in
      match parts with
      | _ :: name_str :: _ ->
          let name = parse_name name_str in
          { acc with types = { name; location } :: acc.types }
      | _ -> acc)
  | "str_module" ->
      let name =
        match quoted_string token.content with
        | Some str -> parse_name str
        | None -> parse_name (String.trim token.content)
      in
      { acc with modules = { name; location } :: acc.modules }
  | _ ->
      if
        String.contains token.content '/'
        && not (String.contains token.content ' ')
      then
        let name = parse_name token.content in
        { acc with variants = { name; location } :: acc.variants }
      else acc

(** Check if token looks like a variant constructor *)
let is_variant_constructor token =
  String.contains token.content '/' && not (String.contains token.content ' ')

(** Process a single token and update the accumulator *)
let process_single_token acc location token current_what in_variant_section =
  if is_variant_constructor token && in_variant_section then
    (* Variant constructor like ProcessingData/278 *)
    let name = parse_name token.content in
    { acc with variants = { name; location } :: acc.variants }
  else
    let node_type = get_node_type token.content in
    let normalized = safe_normalize_node_type current_what node_type in
    extract_name_from_token acc location normalized token

(** Process tokens and extract all names/identifiers *)
let process_tokens what tokens =
  let rec process_tokens_rec acc prev_token current_what in_variant_section
      tokens =
    match tokens with
    | [] -> acc
    | token :: rest ->
        let node_type = get_node_type token.content in
        let new_what = determine_what current_what token node_type in
        let new_in_variant_section =
          update_variant_section in_variant_section token node_type
        in
        let location =
          match prev_token with Some pt -> pt.loc | None -> token.loc
        in
        let new_acc =
          process_single_token acc location token new_what
            new_in_variant_section
        in
        process_tokens_rec new_acc (Some token) new_what new_in_variant_section
          rest
  in
  process_tokens_rec empty_acc None what false tokens

(** Parse AST text with specific what (for testing) *)
let text what input =
  (* Phase 1: Lex the text into tokens *)
  let tokens = lex_text ~parse_loc_from_line:true input in
  (* Phase 2: Process tokens to extract names *)
  process_tokens what tokens

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
  | Parse_error msg
    when String.length msg > 19 && String.sub msg 0 19 = "Found Parsetree node"
    ->
      (* Parse error due to Parsetree nodes in Typedtree dump - fall back *)
      Log.debug (fun m ->
          m "Parsetree nodes in Typedtree dump, falling back: %s" msg);
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
