(** OCamlmerlin outline output - structured representation *)

type kind =
  | Value
  | Type
  | Module
  | Class
  | Exception
  | Constructor
  | Field
  | Method
  | Other of string

type position = { line : int; col : int }
type range = { start : position; end_ : position }

type item = {
  name : string;
  kind : kind;
  type_sig : string option; (* Type signature for values *)
  range : range option;
}

type t = item list

(** Parse kind from string *)
let parse_kind = function
  | "Value" -> Value
  | "Type" -> Type
  | "Module" -> Module
  | "Class" -> Class
  | "Exn" | "Exception" -> Exception (* Merlin outputs "Exn" *)
  | "Constructor" -> Constructor
  | "Field" -> Field
  | "Method" -> Method
  | s -> Other s

(** Parse position from JSON *)
let parse_position json =
  match json with
  | `Assoc items ->
      let line =
        match List.assoc_opt "line" items with Some (`Int l) -> l | _ -> 0
      in
      let col =
        match List.assoc_opt "col" items with Some (`Int c) -> c | _ -> 0
      in
      { line; col }
  | _ -> { line = 0; col = 0 }

(** Parse range from JSON *)
let parse_range json =
  match json with
  | `Assoc items ->
      let start =
        match List.assoc_opt "start" items with
        | Some pos -> parse_position pos
        | None -> { line = 0; col = 0 }
      in
      let end_ =
        match List.assoc_opt "end" items with
        | Some pos -> parse_position pos
        | None -> { line = 0; col = 0 }
      in
      Some { start; end_ }
  | _ -> None

(** Parse item from JSON *)
let parse_item json =
  match json with
  | `Assoc items ->
      let name =
        match List.assoc_opt "name" items with Some (`String n) -> n | _ -> ""
      in
      let kind =
        match List.assoc_opt "kind" items with
        | Some (`String k) -> parse_kind k
        | _ -> Other "unknown"
      in
      let type_sig =
        match List.assoc_opt "type" items with
        | Some (`String t) -> Some t
        | _ -> None
      in
      let range =
        (* Merlin provides start and end directly, not under location *)
        parse_range json
      in
      Some { name; kind; type_sig; range }
  | _ -> None

(** Parse outline from JSON *)
let of_json json =
  match json with `List items -> List.filter_map parse_item items | _ -> []

(** Get all values from outline *)
let get_values outline = List.filter (fun item -> item.kind = Value) outline

(** Find item by name *)
let find_by_name name outline =
  List.find_opt (fun item -> item.name = name) outline

(** Pretty print kind *)
let pp_kind ppf = function
  | Value -> Fmt.pf ppf "value"
  | Type -> Fmt.pf ppf "type"
  | Module -> Fmt.pf ppf "module"
  | Class -> Fmt.pf ppf "class"
  | Exception -> Fmt.pf ppf "exception"
  | Constructor -> Fmt.pf ppf "constructor"
  | Field -> Fmt.pf ppf "field"
  | Method -> Fmt.pf ppf "method"
  | Other s -> Fmt.pf ppf "other(%s)" s

(** Pretty print position *)
let pp_position ppf pos = Fmt.pf ppf "%d:%d" pos.line pos.col

(** Pretty print range *)
let pp_range ppf range =
  Fmt.pf ppf "%a-%a" pp_position range.start pp_position range.end_

(** Pretty print item *)
let pp_item ppf item =
  let type_str =
    match item.type_sig with Some t -> Fmt.str ": %s" t | None -> ""
  in
  match item.range with
  | Some range ->
      Fmt.pf ppf "%s (%a)%s at %a" item.name pp_kind item.kind type_str pp_range
        range
  | None -> Fmt.pf ppf "%s (%a)%s" item.name pp_kind item.kind type_str

(** Pretty print outline *)
let pp ppf outline =
  Fmt.pf ppf "@[<v>%a@]" (Fmt.list ~sep:Fmt.cut pp_item) outline
