(** Simplified Typedtree parser for identifier extraction *)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type expr_node =
  | Construct of { name : string; args : expr_node list }
  | Apply of { func : expr_node; args : expr_node list }
  | Ident of string
  | Constant of string
  | Other

type t = {
  identifiers : elt list;
  patterns : elt list;
  modules : elt list;
  types : elt list;
  exceptions : elt list;
  variants : elt list;
  expressions : (expr_node * Location.t option) list;
}
(** Simplified representation focusing on identifiers *)

(** Compiled regex for extracting quoted strings *)
let quote_regex =
  Re.compile
    (Re.seq
       [
         Re.str "\""; Re.group (Re.rep (Re.compl [ Re.char '"' ])); Re.str "\"";
       ])

(** Extract quoted string from line *)
let extract_quoted_string line =
  try
    let m = Re.exec quote_regex line in
    Some (Re.Group.get m 1)
  with Not_found -> None

(** Parse a structured name from a string like "Stdlib!.Obj.magic" The '!'
    suffix on module names appears to indicate the fully qualified module path
    as resolved by the type-checker (e.g., both Obj.magic and Stdlib.Obj.magic
    appear as "Stdlib!.Obj.magic" in the typedtree) *)
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
      (* Process modules to handle ! separator - remove it as it's just a marker *)
      let prefix =
        List.fold_left
          (fun acc m ->
            (* Remove ! suffix from module names *)
            let len = String.length m in
            let m =
              if len > 0 && m.[len - 1] = '!' then String.sub m 0 (len - 1)
              else m
            in
            m :: acc)
          [] rev_modules
      in
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

(** Compiled regex for parsing locations *)
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

let parse_location str =
  (* Format: (filename[line,char+col]..filename[line,char+col]) *)
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
    expressions = [];
  }

(** Pre-process the raw text into a list of blocks *)
let preprocess_text text =
  let get_indent line =
    let len = String.length line in
    let rec count i = if i < len && line.[i] = ' ' then count (i + 1) else i in
    count 0
  in
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let len = String.length line in
         if len = 0 then None
         else
           let indent = get_indent line in
           let trimmed = String.trim line in
           if trimmed = "" then None
           else
             (* Only parse location if line contains location pattern *)
             let loc =
               if String.contains line '(' && String.contains line '[' then
                 parse_location line
               else None
             in
             Some { indent; content = trimmed; loc })

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
    identifiers = List.rev_append child_acc.identifiers acc.identifiers;
    patterns = List.rev_append child_acc.patterns acc.patterns;
    modules = List.rev_append child_acc.modules acc.modules;
    types = List.rev_append child_acc.types acc.types;
    exceptions = List.rev_append child_acc.exceptions acc.exceptions;
    variants = List.rev_append child_acc.variants acc.variants;
    expressions = List.rev_append child_acc.expressions acc.expressions;
  }

(** Process expression node *)
let rec process_expression blocks_ref indent loc acc =
  (* Process all children of the expression *)
  let child_acc = parse_node blocks_ref (indent + 2) loc empty_acc in
  merge_acc child_acc acc

(** Process pattern node *)
and process_pattern blocks_ref indent loc acc =
  let child_acc = parse_node blocks_ref (indent + 2) loc empty_acc in
  {
    acc with
    patterns = List.rev_append child_acc.patterns acc.patterns;
    variants = List.rev_append child_acc.variants acc.variants;
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
      { acc with modules = List.rev_append child_acc.modules acc.modules }

(** Process module binding *)
and process_module_binding blocks_ref block current_loc acc =
  match peek_block blocks_ref with
  | Some next_block when next_block.indent > block.indent -> (
      match extract_quoted_string next_block.content with
      | Some name_str ->
          let _ = consume_block blocks_ref in
          let name = parse_name name_str in
          let result =
            {
              acc with
              modules = { name; location = current_loc } :: acc.modules;
            }
          in
          (* Continue parsing children *)
          parse_node blocks_ref (block.indent + 2) current_loc result
      | None ->
          (* Continue parsing, module name might be deeper *)
          parse_node blocks_ref (block.indent + 2) current_loc acc)
  | _ -> acc

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

      (* Extract the node type (e.g., "Texp_ident") from the content *)
      let node_type =
        try
          let i = String.index content ' ' in
          String.sub content 0 i
        with Not_found -> content
      in

      let new_acc =
        match node_type with
        | "expression" ->
            process_expression blocks_ref block.indent current_loc acc
        | "pattern" -> process_pattern blocks_ref block.indent current_loc acc
        | "Texp_ident" -> process_ident content parent_location acc
        | "Tpat_var" -> process_var_pattern content parent_location acc
        | "Tstr_module" ->
            process_module blocks_ref content block.indent current_loc acc
        | "module_binding" ->
            process_module_binding blocks_ref block current_loc acc
        | "Tstr_type" -> process_type content current_loc acc
        | "Tstr_exception" -> process_exception content current_loc acc
        | "Tpat_construct" -> process_variant content parent_location acc
        | _ -> process_other blocks_ref block.indent current_loc acc
      in
      (* Continue parsing at the same level *)
      parse_node blocks_ref current_indent parent_location new_acc

(** Parse identifiers from blocks *)
let parse_from_blocks (blocks : block list) : t =
  let blocks_ref = ref blocks in
  let initial_acc = empty_acc in
  let result = parse_node blocks_ref 0 None initial_acc in
  (* Reverse to maintain order *)
  {
    identifiers = List.rev result.identifiers;
    patterns = List.rev result.patterns;
    modules = List.rev result.modules;
    types = List.rev result.types;
    exceptions = List.rev result.exceptions;
    variants = List.rev result.variants;
    expressions = List.rev result.expressions;
  }

(** Parse typedtree output from raw text *)
let of_text text =
  let blocks = preprocess_text text in
  parse_from_blocks blocks

(** Parse typedtree output from JSON (legacy) *)
let of_json json = match json with `String str -> of_text str | _ -> empty_acc

(** Parse typedtree output from JSON with filename correction *)
let of_json_with_filename json original_filename =
  match json with
  | `String str ->
      let result = of_text str in
      (* Only fix filenames if we have any locations *)
      if
        result.identifiers = [] && result.patterns = [] && result.modules = []
        && result.types = [] && result.exceptions = [] && result.variants = []
        && result.expressions = []
      then result
      else
        (* Fix filenames in all locations *)
        let fix_location_filename loc =
          match loc with
          | None -> None
          | Some l -> Some { l with Location.file = original_filename }
        in
        let fix_elt elt =
          { elt with location = fix_location_filename elt.location }
        in
        let fix_expr (expr, loc) = (expr, fix_location_filename loc) in
        {
          identifiers = List.map fix_elt result.identifiers;
          patterns = List.map fix_elt result.patterns;
          modules = List.map fix_elt result.modules;
          types = List.map fix_elt result.types;
          exceptions = List.map fix_elt result.exceptions;
          variants = List.map fix_elt result.variants;
          expressions = List.map fix_expr result.expressions;
        }
  | _ -> empty_acc

(** Convert a structured name to a string *)
let name_to_string (n : name) =
  match n.prefix with
  | [] -> n.base
  | prefix -> String.concat "." prefix ^ "." ^ n.base

(** Pretty print *)
let pp ppf t = Fmt.pf ppf "{ identifiers: %d }" (List.length t.identifiers)
