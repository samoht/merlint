(** Context for rule checking - holds all parameters and data needed by rules *)

let src = Logs.Src.create "merlint.context" ~doc:"Context management"

module Log = (val Logs.src_log src : Logs.LOG)

exception Analysis_error of string

type file = {
  filename : string;
  config : Config.t;
  project_root : string;
  ast : Ast.t Lazy.t;
  dump : Dump.t Lazy.t;
  outline : Outline.t Lazy.t;
  content : string Lazy.t;
  functions : (string * Ast.expr) list Lazy.t;
}

type project = {
  config : Config.t;
  project_root : string;
  all_files : string list Lazy.t;
  dune_describe : Dune.describe Lazy.t;
  executable_modules : string list Lazy.t;
  lib_modules : string list Lazy.t;
  test_modules : string list Lazy.t;
}

let file ~filename ~config ~project_root ~merlin_result =
  {
    filename;
    config;
    project_root;
    ast = lazy { Ast.functions = Ast.extract_functions filename };
    dump =
      lazy
        (match merlin_result.Merlin.dump with
        | Ok dump -> dump
        | Error msg -> raise (Analysis_error msg));
    outline =
      lazy
        (match merlin_result.Merlin.outline with
        | Ok o -> o
        | Error msg -> raise (Analysis_error msg));
    content =
      lazy
        (try In_channel.with_open_text filename In_channel.input_all
         with exn ->
           raise
             (Analysis_error
                (Fmt.str "Failed to read file %s: %s" filename
                   (Printexc.to_string exn))));
    functions =
      lazy
        (let ast = Ast.extract_functions filename in
         Log.debug (fun m ->
             m "Context: extracted %d functions" (List.length ast));
         ast);
  }

let project ~config ~project_root ~all_files ~dune_describe =
  let dune_desc_lazy = lazy dune_describe in
  {
    config;
    project_root;
    all_files =
      lazy
        (Log.debug (fun m ->
             m "Context: Total files to analyze: %d" (List.length all_files));
         (* Check specifically for test_author.ml and similar *)
         let specific_test_files =
           [ "test_author.ml"; "test_blog.ml"; "test_build.ml" ]
         in
         List.iter
           (fun name ->
             let found =
               List.exists (fun f -> String.ends_with ~suffix:name f) all_files
             in
             if found then
               let path =
                 List.find (fun f -> String.ends_with ~suffix:name f) all_files
               in
               Log.debug (fun m -> m "Context: Found %s at: %s" name path)
             else Log.debug (fun m -> m "Context: NOT FOUND: %s" name))
           specific_test_files;
         all_files);
    dune_describe = dune_desc_lazy;
    executable_modules =
      lazy (Dune.executable_modules (Lazy.force dune_desc_lazy));
    lib_modules = lazy (Dune.lib_modules (Lazy.force dune_desc_lazy));
    test_modules =
      lazy
        ((* Get test modules from dune describe *)
         let dune_test_modules =
           Dune.test_modules (Lazy.force dune_desc_lazy)
         in
         (* Also discover test_*.ml files from all_files that might not be in dune *)
         let file_test_modules =
           all_files
           |> List.filter_map (fun f ->
                  if String.ends_with ~suffix:".ml" f then
                    let basename =
                      Filename.basename f |> Filename.remove_extension
                    in
                    if
                      String.starts_with ~prefix:"test_" basename
                      || basename = "test"
                    then (
                      Log.debug (fun m ->
                          m "Context: Found test file %s -> module %s" f
                            basename);
                      Some basename)
                    else None
                  else None)
         in
         (* Combine and deduplicate *)
         let all_test_modules =
           dune_test_modules @ file_test_modules
           |> List.sort_uniq String.compare
         in
         Log.debug (fun m ->
             m "Context: Total test modules: %d (dune: %d, files: %d)"
               (List.length all_test_modules)
               (List.length dune_test_modules)
               (List.length file_test_modules));
         Log.debug (fun m ->
             m "Context: All test modules: %a"
               Fmt.(list ~sep:comma string)
               all_test_modules);
         all_test_modules);
  }

(* File context accessors *)
let ast ctx = Lazy.force ctx.ast
let dump ctx = Lazy.force ctx.dump
let outline ctx = Lazy.force ctx.outline
let content ctx = Lazy.force ctx.content
let functions ctx = Lazy.force ctx.functions

(* Project context accessors *)
let all_files ctx = Lazy.force ctx.all_files
let executable_modules ctx = Lazy.force ctx.executable_modules
let lib_modules ctx = Lazy.force ctx.lib_modules
let test_modules ctx = Lazy.force ctx.test_modules
let dune_describe ctx = Lazy.force ctx.dune_describe
