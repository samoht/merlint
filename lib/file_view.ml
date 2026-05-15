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
    lazy (match dump () with Ok d -> d | Error msg -> fail "%s" msg)
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

let dump t =
  let d = Lazy.force t.dump in
  Merlin.Dump.fix_all_paths ~full_path:t.filename d

let outline t = Lazy.force t.outline
