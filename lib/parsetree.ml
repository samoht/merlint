(** Parsetree parser for fallback identifier extraction *)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type t = {
  identifiers : elt list;
  patterns : elt list;
  modules : elt list;
  types : elt list;
  exceptions : elt list;
  variants : elt list;
}
(** Simplified representation focusing on identifiers *)

(** Extract quoted string from line *)
let extract_quoted_string line =
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

(** Parse a structured name from a string like "Str.regexp" *)
let parse_name str =
  (* Remove unique suffix like /123 if present *)
  let str =
    match String.index_opt str '/' with
    | Some i -> String.sub str 0 i
    | None -> str
  in
  (* Split by . to get components *)
  let parts = String.split_on_char '.' str in
  match List.rev parts with
  | [] -> { prefix = []; base = "" }
  | base :: rev_modules ->
      let prefix = List.rev rev_modules in
      { prefix; base }

(** Helper regex components for location parsing *)
let filename = Re.rep1 (Re.compl [ Re.char '[' ])

let number = Re.rep1 Re.digit

let location_part =
  Re.seq
    [
      Re.str "[";
      Re.group number;
      (* line *)
      Re.str ",";
      number;
      (* char position - not captured *)
      Re.str "+";
      Re.group number;
      (* column *)
      Re.str "]";
    ]

let parse_location str =
  (* Format: (filename[line,char+col]..filename[line,char+col]) *)
  let loc_regex =
    Re.compile
      (Re.seq
         [
           Re.str "(";
           Re.group filename;
           (* filename *)
           location_part;
           (* start location *)
           Re.str "..";
           filename;
           (* second filename - not captured *)
           location_part;
           (* end location *)
           Re.str ")";
         ])
  in
  try
    let m = Re.exec loc_regex str in
    let file = Re.Group.get m 1 in
    let start_line = int_of_string (Re.Group.get m 2) in
    let start_col = int_of_string (Re.Group.get m 3) in
    let end_line = int_of_string (Re.Group.get m 4) in
    let end_col = int_of_string (Re.Group.get m 5) in
    Some (Location.create ~file ~start_line ~start_col ~end_line ~end_col)
  with Not_found -> None

type block = { indent : int; content : string; loc : Location.t option }
(** A block is the fundamental unit, not a line *)

(** Empty accumulator for reuse *)
let empty_acc =
  {
    identifiers = [];
    patterns = [];
    modules = [];
    types = [];
    exceptions = [];
    variants = [];
  }

(** Pre-process the raw text into a list of blocks *)
let preprocess_text text =
  let get_indent line =
    let rec count i =
      if i < String.length line && line.[i] = ' ' then count (i + 1) else i
    in
    count 0
  in
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let trimmed = String.trim line in
         if trimmed = "" then None
         else
           Some
             {
               indent = get_indent line;
               content = trimmed;
               loc = parse_location line;
             })

(** Helper to peek at the next block without consuming it *)
let peek_block (blocks_ref : block list ref) =
  match !blocks_ref with h :: _ -> Some h | [] -> None

(** Helper to consume the next block *)
let consume_block (blocks_ref : block list ref) =
  match !blocks_ref with
  | h :: t ->
      blocks_ref := t;
      Some h
  | [] -> None

(** Merge two accumulators *)
let merge_acc child_acc acc =
  {
    identifiers = child_acc.identifiers @ acc.identifiers;
    patterns = child_acc.patterns @ acc.patterns;
    modules = child_acc.modules @ acc.modules;
    types = child_acc.types @ acc.types;
    exceptions = child_acc.exceptions @ acc.exceptions;
    variants = child_acc.variants @ acc.variants;
  }

(** Process expression node *)
let rec process_expression blocks_ref indent loc acc =
  let child_acc = parse_node blocks_ref (indent + 2) loc empty_acc in
  merge_acc child_acc acc

(** Process pattern node *)
and process_pattern blocks_ref indent loc acc =
  let child_acc = parse_node blocks_ref (indent + 2) loc empty_acc in
  {
    acc with
    patterns = child_acc.patterns @ acc.patterns;
    variants = child_acc.variants @ acc.variants;
  }

(** Process identifier node *)
and process_ident content parent_location acc =
  let name = extract_quoted_string content |> Option.map parse_name in
  match name with
  | Some n ->
      {
        acc with
        identifiers =
          { name = n; location = parent_location } :: acc.identifiers;
      }
  | None -> acc

(** Process variable pattern *)
and process_var_pattern content parent_location acc =
  let name = extract_quoted_string content |> Option.map parse_name in
  match name with
  | Some n ->
      {
        acc with
        patterns = { name = n; location = parent_location } :: acc.patterns;
      }
  | None -> acc

(** Process module declaration *)
and process_module blocks_ref content indent current_loc acc =
  match extract_quoted_string content with
  | Some name_str ->
      let name = parse_name name_str in
      { acc with modules = { name; location = current_loc } :: acc.modules }
  | None ->
      (* Look in children for module_binding with the name *)
      let child_acc =
        parse_node blocks_ref (indent + 2) current_loc empty_acc
      in
      { acc with modules = child_acc.modules @ acc.modules }

(** Process type declaration *)
and process_type content current_loc acc =
  let name = extract_quoted_string content |> Option.map parse_name in
  match name with
  | Some n ->
      { acc with types = { name = n; location = current_loc } :: acc.types }
  | None -> acc

(** Process exception declaration *)
and process_exception content current_loc acc =
  let name = extract_quoted_string content |> Option.map parse_name in
  match name with
  | Some n ->
      {
        acc with
        exceptions = { name = n; location = current_loc } :: acc.exceptions;
      }
  | None -> acc

(** Process variant constructor *)
and process_variant content parent_location acc =
  let name = extract_quoted_string content |> Option.map parse_name in
  match name with
  | Some n ->
      {
        acc with
        variants = { name = n; location = parent_location } :: acc.variants;
      }
  | None -> acc

(** Process any other node by parsing its children *)
and process_other blocks_ref indent current_loc acc =
  let child_acc = parse_node blocks_ref (indent + 2) current_loc empty_acc in
  merge_acc child_acc acc

(** The main recursive parsing function *)
and parse_node (blocks_ref : block list ref) (current_indent : int)
    (parent_location : Location.t option) (acc : t) : t =
  match peek_block blocks_ref with
  | None -> acc (* End of input *)
  | Some block when block.indent < current_indent -> acc (* End of this level *)
  | Some block when block.indent > current_indent ->
      (* Skip children that are too deeply indented - shouldn't happen at this level *)
      let _ = consume_block blocks_ref in
      parse_node blocks_ref current_indent parent_location acc
  | Some block ->
      let _ = consume_block blocks_ref in
      (* Consume the block we're processing *)
      let content = block.content in

      (* Get the location from this block, or inherit from parent *)
      let current_loc =
        match block.loc with Some loc -> Some loc | None -> parent_location
      in

      (* Extract the node type (e.g., "Pexp_ident") from the content *)
      let node_type =
        match String.index_opt content ' ' with
        | Some i -> String.sub content 0 i
        | None -> content
      in

      let new_acc =
        match node_type with
        | "expression" ->
            process_expression blocks_ref block.indent current_loc acc
        | "pattern" -> process_pattern blocks_ref block.indent current_loc acc
        | "Pexp_ident" -> process_ident content parent_location acc
        | "Ppat_var" -> process_var_pattern content parent_location acc
        | "Ppat_any" ->
            (* Catch-all pattern _ *)
            let name = { prefix = []; base = "_" } in
            {
              acc with
              patterns = { name; location = parent_location } :: acc.patterns;
            }
        | "Pstr_module" ->
            process_module blocks_ref content block.indent current_loc acc
        | "Pstr_type" -> process_type content current_loc acc
        | "Pstr_exception" -> process_exception content current_loc acc
        | "Ppat_construct" -> process_variant content parent_location acc
        | _ -> process_other blocks_ref block.indent current_loc acc
      in
      (* Continue parsing at the same level *)
      parse_node blocks_ref current_indent parent_location new_acc

(** Parse identifiers from blocks *)
let parse_from_blocks (blocks : block list) : t =
  let blocks_ref = ref blocks in
  let result = parse_node blocks_ref 0 None empty_acc in
  (* Reverse to maintain order *)
  {
    identifiers = List.rev result.identifiers;
    patterns = List.rev result.patterns;
    modules = List.rev result.modules;
    types = List.rev result.types;
    exceptions = List.rev result.exceptions;
    variants = List.rev result.variants;
  }

(** Parse parsetree output from raw text *)
let of_text text =
  let blocks = preprocess_text text in
  parse_from_blocks blocks

(** Parse parsetree output from JSON *)
let of_json json =
  match json with
  | `String str -> of_text str
  | _ ->
      {
        identifiers = [];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
      }

(** Parse parsetree output from JSON with filename correction *)
let of_json_with_filename json original_filename =
  match json with
  | `String str ->
      let result = of_text str in
      (* Fix filenames in all locations *)
      let fix_location_filename loc =
        match loc with
        | None -> None
        | Some l -> Some { l with Location.file = original_filename }
      in
      let fix_elt elt =
        { elt with location = fix_location_filename elt.location }
      in
      {
        identifiers = List.map fix_elt result.identifiers;
        patterns = List.map fix_elt result.patterns;
        modules = List.map fix_elt result.modules;
        types = List.map fix_elt result.types;
        exceptions = List.map fix_elt result.exceptions;
        variants = List.map fix_elt result.variants;
      }
  | _ ->
      {
        identifiers = [];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
      }

(** Convert a structured name to a string *)
let name_to_string (n : name) =
  match n.prefix with
  | [] -> n.base
  | prefix -> String.concat "." prefix ^ "." ^ n.base

(** Pretty print *)
let pp ppf t = Fmt.pf ppf "{ identifiers: %d }" (List.length t.identifiers)
