(** Common AST types and utilities shared between parsetree and typedtree *)

type name = { prefix : string list; base : string }
(** Structured name type *)

type elt = { name : name; location : Location.t option }
(** Common element type for all extracted items *)

type block = { indent : int; content : string; loc : Location.t option }
(** A block is the fundamental unit, not a line *)

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

(** Parse a structured name from a string like "Str.regexp" or
    "Stdlib!.Obj.magic"
    @param handle_bang_suffix
      if true, removes '!' suffix from module names (for typedtree) *)
let parse_name ?(handle_bang_suffix = false) str =
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
      let prefix =
        if handle_bang_suffix then
          (* Process modules to handle ! separator - remove it as it's just a marker *)
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
        else List.rev rev_modules
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

(** Parse location from string format:
    (filename[line,char+col]..filename[line,char+col]) *)
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

(** Pre-process the raw text into a list of blocks
    @param parse_loc_from_line
      if true, parse location from lines containing location patterns *)
let preprocess_text ?(parse_loc_from_line = true) text =
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
             let loc =
               if parse_loc_from_line then parse_location line else None
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

(** Convert a structured name to a string *)
let name_to_string (n : name) =
  match n.prefix with
  | [] -> n.base
  | prefix -> String.concat "." prefix ^ "." ^ n.base

(** Extract line and column from parsetree text like
    "(file.ml[2,27+16]..[2,27+25])" *)
let extract_location_from_parsetree text =
  let location_regex =
    Re.compile
      (Re.seq
         [
           Re.str "(";
           Re.group (Re.rep1 (Re.compl [ Re.char '[' ]));
           Re.str "[";
           Re.group (Re.rep1 Re.digit);
           Re.str ",";
           Re.rep1 Re.digit;
           Re.str "+";
           Re.group (Re.rep1 Re.digit);
           Re.str "]";
         ])
  in
  try
    let substrings = Re.exec location_regex text in
    let line = int_of_string (Re.Group.get substrings 2) in
    let col = int_of_string (Re.Group.get substrings 3) in
    Some (line, col)
  with Not_found -> None

(** Extract filename from parsetree text, returns "unknown" if not found *)
let extract_filename_from_parsetree text =
  let filename_regex =
    Re.compile
      (Re.seq
         [
           Re.str "("; Re.group (Re.rep1 (Re.compl [ Re.char '[' ])); Re.str "[";
         ])
  in
  try
    let substrings = Re.exec filename_regex text in
    Re.Group.get substrings 1
  with Not_found -> "unknown"

type dialect = Parsetree | Typedtree

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

(** Empty accumulator *)
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
let rec process_expression ~dialect blocks_ref indent loc acc =
  let child_acc = parse_node ~dialect blocks_ref (indent + 2) loc empty_acc in
  merge_acc child_acc acc

(** Process pattern node *)
and process_pattern ~dialect blocks_ref indent loc acc =
  let child_acc = parse_node ~dialect blocks_ref (indent + 2) loc empty_acc in
  {
    acc with
    patterns = List.rev_append child_acc.patterns acc.patterns;
    variants = List.rev_append child_acc.variants acc.variants;
  }

(** Process identifier node *)
and process_ident ~dialect content parent_location acc =
  let handle_bang_suffix = dialect = Typedtree in
  let name =
    extract_quoted_string content |> Option.map (parse_name ~handle_bang_suffix)
  in
  match name with
  | Some n ->
      {
        acc with
        identifiers =
          { name = n; location = parent_location } :: acc.identifiers;
      }
  | None -> acc

(** Process variable pattern *)
and process_var_pattern ~dialect content parent_location acc =
  let handle_bang_suffix = dialect = Typedtree in
  let name =
    extract_quoted_string content |> Option.map (parse_name ~handle_bang_suffix)
  in
  match name with
  | Some n ->
      {
        acc with
        patterns = { name = n; location = parent_location } :: acc.patterns;
      }
  | None -> acc

(** Process module declaration *)
and process_module ~dialect blocks_ref content indent current_loc acc =
  let handle_bang_suffix = dialect = Typedtree in
  match extract_quoted_string content with
  | Some name_str ->
      let name = parse_name ~handle_bang_suffix name_str in
      { acc with modules = { name; location = current_loc } :: acc.modules }
  | None ->
      (* Look in children for module_binding with the name *)
      let child_acc =
        parse_node ~dialect blocks_ref (indent + 2) current_loc empty_acc
      in
      { acc with modules = List.rev_append child_acc.modules acc.modules }

(** Process type declaration *)
and process_type ~dialect content current_loc acc =
  let handle_bang_suffix = dialect = Typedtree in
  let name =
    extract_quoted_string content |> Option.map (parse_name ~handle_bang_suffix)
  in
  match name with
  | Some n ->
      { acc with types = { name = n; location = current_loc } :: acc.types }
  | None -> acc

(** Process exception declaration *)
and process_exception ~dialect content current_loc acc =
  let handle_bang_suffix = dialect = Typedtree in
  let name =
    extract_quoted_string content |> Option.map (parse_name ~handle_bang_suffix)
  in
  match name with
  | Some n ->
      {
        acc with
        exceptions = { name = n; location = current_loc } :: acc.exceptions;
      }
  | None -> acc

(** Process variant constructor *)
and process_variant ~dialect content parent_location acc =
  let handle_bang_suffix = dialect = Typedtree in
  let name =
    extract_quoted_string content |> Option.map (parse_name ~handle_bang_suffix)
  in
  match name with
  | Some n ->
      {
        acc with
        variants = { name = n; location = parent_location } :: acc.variants;
      }
  | None -> acc

(** Process children of a node *)
and process_other ~dialect blocks_ref indent current_loc acc =
  let child_acc =
    parse_node ~dialect blocks_ref (indent + 2) current_loc empty_acc
  in
  merge_acc child_acc acc

(** Generic parse node function *)
and parse_node ~dialect (blocks_ref : block list ref) (current_indent : int)
    (parent_location : Location.t option) (acc : t) : t =
  match peek_block blocks_ref with
  | None -> acc (* End of input *)
  | Some block when block.indent < current_indent -> acc (* End of this level *)
  | Some block when block.indent > current_indent ->
      (* Skip children that are too deeply indented *)
      let _ = consume_block blocks_ref in
      parse_node ~dialect blocks_ref current_indent parent_location acc
  | Some block ->
      let _ = consume_block blocks_ref in
      let content = block.content in

      (* Get the location from this block, or inherit from parent *)
      let current_loc =
        match block.loc with Some loc -> Some loc | None -> parent_location
      in

      (* Extract the node type from the content *)
      let node_type =
        match String.index_opt content ' ' with
        | Some idx -> String.sub content 0 idx
        | None -> content
      in

      (* Map node types based on dialect *)
      let node_type =
        match dialect with
        | Parsetree -> node_type
        | Typedtree -> (
            (* For typedtree, some nodes use the same names as parsetree *)
            match node_type with
            | "expression" | "pattern" | "structure_item" | "module_binding"
            | "type_declaration" | "extension_constructor" ->
                node_type
            | _ -> node_type)
      in

      let new_acc =
        match node_type with
        | "expression" ->
            process_expression ~dialect blocks_ref block.indent current_loc acc
        | "pattern" ->
            process_pattern ~dialect blocks_ref block.indent current_loc acc
        | "Pexp_ident" | "Texp_ident" ->
            process_ident ~dialect content parent_location acc
        | "Ppat_var" | "Tpat_var" ->
            process_var_pattern ~dialect content parent_location acc
        | "Ppat_any" when dialect = Parsetree ->
            (* Catch-all pattern _ *)
            let name = { prefix = []; base = "_" } in
            {
              acc with
              patterns = { name; location = parent_location } :: acc.patterns;
            }
        | "Pstr_module" | "Tstr_module" ->
            process_module ~dialect blocks_ref content block.indent current_loc
              acc
        | "Pstr_type" | "Tstr_type" ->
            process_type ~dialect content current_loc acc
        | "Pstr_exception" | "Tstr_exception" ->
            process_exception ~dialect content current_loc acc
        | "Ppat_construct" | "Tpat_construct" ->
            process_variant ~dialect content parent_location acc
        | "module_binding" ->
            (* Special handling for module_binding in both dialects *)
            let child_acc =
              parse_node ~dialect blocks_ref (block.indent + 2) current_loc
                empty_acc
            in
            { acc with modules = List.rev_append child_acc.modules acc.modules }
        | "type_declaration" ->
            (* Look for ptype_name/type_name child *)
            let child_acc =
              parse_node ~dialect blocks_ref (block.indent + 2) current_loc
                empty_acc
            in
            { acc with types = List.rev_append child_acc.types acc.types }
        | "extension_constructor" ->
            (* Look for pext_name child *)
            let child_acc =
              parse_node ~dialect blocks_ref (block.indent + 2) current_loc
                empty_acc
            in
            {
              acc with
              exceptions = List.rev_append child_acc.exceptions acc.exceptions;
            }
        | _ -> process_other ~dialect blocks_ref block.indent current_loc acc
      in
      (* Continue parsing at the same level *)
      parse_node ~dialect blocks_ref current_indent parent_location new_acc

(** Parse from blocks *)
let parse_from_blocks ~dialect (blocks : block list) : t =
  let blocks_ref = ref blocks in
  let result = parse_node ~dialect blocks_ref 0 None empty_acc in
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

(** Parse AST output from raw text *)
let of_text ~dialect text =
  let blocks = preprocess_text ~parse_loc_from_line:true text in
  parse_from_blocks ~dialect blocks

(** Parse AST output from JSON *)
let of_json ~dialect ~filename json =
  match json with
  | `String _str ->
      let text = Yojson.Safe.to_string json in
      (* Fix the filename in the text if needed *)
      let fixed_text =
        if dialect = Parsetree && not (String.equal filename "unknown") then
          let regex =
            Re.compile
              (Re.seq [ Re.str "(_none_["; Re.rep1 Re.any; Re.str "]" ])
          in
          Re.replace_string regex ~by:(filename ^ "[") text
        else text
      in
      of_text ~dialect fixed_text
  | _ -> empty_acc

(** Pretty print *)
let pp fmt t =
  let pp_list name pp_item fmt items =
    if items <> [] then
      Fmt.pf fmt "@[<v 2>%s:@ %a@]@." name (Fmt.list ~sep:Fmt.cut pp_item) items
  in
  let pp_elt fmt elt = Fmt.pf fmt "%s" (name_to_string elt.name) in
  Fmt.pf fmt "@[<v>";
  pp_list "Identifiers" pp_elt fmt t.identifiers;
  pp_list "Patterns" pp_elt fmt t.patterns;
  pp_list "Modules" pp_elt fmt t.modules;
  pp_list "Types" pp_elt fmt t.types;
  pp_list "Exceptions" pp_elt fmt t.exceptions;
  pp_list "Variants" pp_elt fmt t.variants;
  Fmt.pf fmt "@]"
