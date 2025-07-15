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

type 'acc merge_fn = 'acc -> 'acc -> 'acc
(** Generic merge accumulator function type *)

type 'acc parse_node_fn =
  block list ref -> int -> Location.t option -> 'acc -> 'acc
(** Generic parse node function type *)
