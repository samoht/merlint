let src = Logs.Src.create "merlint.file_view" ~doc:"File view"

module Log = (val Logs.src_log src : Logs.LOG)

exception Analysis_error of string

let fail fmt = Fmt.kstr (fun s -> raise (Analysis_error s)) fmt

type t = {
  filename : string;
  content : string Lazy.t;
  parsetree : Parsetree.structure option Lazy.t;
  functions : (string * Ast.expr) list Lazy.t;
  ast : Ast.t Lazy.t;
  dump : Merlin.Dump.t Lazy.t;
  outline : Outline.t Lazy.t;
}

let v ~filename ~outline ~dump =
  let content =
    lazy
      (try In_channel.with_open_text filename In_channel.input_all
       with exn ->
         fail "Failed to read file %s: %s" filename (Printexc.to_string exn))
  in
  let parsetree =
    lazy
      (let content = Lazy.force content in
       Ast.parse_structure ~filename content)
  in
  let functions =
    lazy
      (match Lazy.force parsetree with
      | None -> []
      | Some structure ->
          let fns = Ast.functions_of_structure structure in
          Log.debug (fun m -> m "File_view: %d functions" (List.length fns));
          fns)
  in
  let ast = lazy { Ast.functions = Lazy.force functions } in
  let dump =
    lazy
      (let d = match dump () with Ok d -> d | Error msg -> fail "%s" msg in
       Merlin.Dump.fix_all_paths ~full_path:filename d)
  in
  let outline =
    lazy (match outline () with Ok o -> o | Error msg -> fail "%s" msg)
  in
  { filename; content; parsetree; functions; ast; dump; outline }

let filename t = t.filename
let content t = Lazy.force t.content
let parsetree t = Lazy.force t.parsetree
let functions t = Lazy.force t.functions
let ast t = Lazy.force t.ast
let dump t = Lazy.force t.dump
let outline t = Lazy.force t.outline

(* {2 Name} *)

module Name = struct
  type t = Merlin.Dump.name

  let to_string = Merlin.Dump.string_of_name
  let base (n : t) = n.base
  let prefix (n : t) = n.prefix
  let equals_path (n : t) path = path = n.prefix @ [ n.base ]
  let pp ppf t = Fmt.string ppf (to_string t)
end

(* {2 Type_view} *)

module Type_view = struct
  type t = Parsetree.core_type

  let is_function (ct : t) =
    match ct.ptyp_desc with Ptyp_arrow _ -> true | _ -> false

  let rec return_type (ct : t) : t option =
    match ct.ptyp_desc with
    | Ptyp_arrow (_, _, ret) -> return_type ret
    | _ -> Some ct

  let rec returns_option (ct : t) =
    match ct.ptyp_desc with
    | Ptyp_arrow (_, _, ret) -> returns_option ret
    | Ptyp_constr ({ txt = Lident "option"; _ }, _) -> true
    | _ -> false

  let count_unlabelled (ct : t) ~match_ =
    let rec aux acc (ct : t) =
      match ct.ptyp_desc with
      | Ptyp_arrow (Nolabel, dom, rest) ->
          let acc = if match_ dom then acc + 1 else acc in
          aux acc rest
      | Ptyp_arrow (_, _, rest) -> aux acc rest
      | _ -> acc
    in
    aux 0 ct

  let pp ppf ct =
    Pprintast.core_type Format.str_formatter ct;
    Fmt.string ppf (Format.flush_str_formatter ())
end

(* {2 Item} *)

module Item = struct
  type kind =
    | Value
    | Type
    | Module
    | Module_type
    | Class
    | Class_type
    | Constructor
    | Exception
    | Field
    | Method
    | Label

  type t = { item : Outline.item; filename : string }

  let kind_of_outline : Outline.kind -> kind = function
    | Value -> Value
    | Type -> Type
    | Module -> Module
    | Module_type -> Module_type
    | Class -> Class
    | Class_type -> Class_type
    | Constructor -> Constructor
    | Exception -> Exception
    | Field -> Field
    | Method -> Method
    | Label -> Label

  let name (t : t) = t.item.name
  let kind (t : t) = kind_of_outline t.item.kind
  let deprecated (t : t) = t.item.deprecated

  let loc (t : t) =
    let loc = t.item.location in
    Location.v ~file:t.filename ~start_line:loc.start.line
      ~start_col:loc.start.col ~end_line:loc.end_.line ~end_col:loc.end_.col

  let type_sig (t : t) = Outline.parsed_type t.item

  let children (t : t) =
    List.map (fun item -> { item; filename = t.filename }) t.item.children
end

(* {2 Reference} *)

module Reference = struct
  type t = Merlin.Dump.elt

  let name (e : t) = e.name
  let loc (e : t) = e.location
end

(* {2 Value_sig} *)

module Value_sig = struct
  type t = Merlin.Dump.value_sig

  let name (v : t) = v.name
  let loc (v : t) = v.location
  let type_path (v : t) = v.type_path
end

(* {2 Call} *)

module Call = struct
  type arg = { arg_expr : Parsetree.expression; arg_filename : string }
  type t = { callee : Merlin.Dump.name; args : arg list; loc : Location.t }

  let callee t = t.callee
  let args t = t.args
  let loc t = t.loc

  let name_of_lident (lid : Longident.t) : Merlin.Dump.name =
    let rec parts acc : Longident.t -> string list = function
      | Lident s -> List.rev (s :: acc)
      | Ldot (l, s) -> parts (s.txt :: acc) l.txt
      | Lapply _ -> List.rev acc
    in
    match parts [] lid with
    | [] -> { prefix = []; base = "" }
    | xs ->
        let rev = List.rev xs in
        { prefix = List.rev (List.tl rev); base = List.hd rev }

  module Arg = struct
    let loc a = Ast.merlint_of_loc ~filename:a.arg_filename a.arg_expr.pexp_loc
    let is_call a ~path = Ast.is_apply_of path a.arg_expr
  end
end

(* {2 Top-level accessors over Outline / Dump} *)

let items t =
  List.map (fun item -> { Item.item; filename = t.filename }) (outline t)

let identifiers t = (dump t).identifiers
let patterns t = (dump t).patterns
let variants t = (dump t).variants
let modules t = (dump t).modules
let types t = (dump t).types
let exceptions t = (dump t).exceptions
let values t = (dump t).values
let signatures t = (dump t).value_sigs

let iter_applications t f =
  match parsetree t with
  | None -> ()
  | Some structure ->
      Ast.iter_apply structure (fun expr fn args ->
          let loc = Ast.merlint_of_loc ~filename:t.filename expr.pexp_loc in
          let args =
            List.map
              (fun (_lbl, e) ->
                { Call.arg_expr = e; arg_filename = t.filename })
              args
          in
          let call = { Call.callee = Call.name_of_lident fn; args; loc } in
          f call)
