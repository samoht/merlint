(** Context for rule checking - holds all parameters and data needed by rules *)

exception Analysis_error of string

type file_context = {
  filename : string;
  config : Config.t;
  project_root : string;
  browse : Browse.t Lazy.t;
  ast : Ast.t Lazy.t;
  outline : Outline.t Lazy.t;
  content : string Lazy.t;
}

type project_context = {
  config : Config.t;
  project_root : string;
  all_files : string list Lazy.t;
  dune_describe : Dune.describe Lazy.t;
  executable_modules : string list Lazy.t;
  lib_modules : string list Lazy.t;
  test_modules : string list Lazy.t;
}

type t = File of file_context | Project of project_context

let create_file ~filename ~config ~project_root ~merlin_result =
  {
    filename;
    config;
    project_root;
    browse =
      lazy
        (match merlin_result.Merlin.browse with
        | Ok b -> b
        | Error msg -> raise (Analysis_error msg));
    ast =
      lazy
        (match merlin_result.Merlin.typedtree with
        | Ok t -> t
        | Error _msg -> (
            (* Fall back to parsetree if typedtree fails *)
            let parsetree_json = Merlin.dump_value "parsetree" filename in
            match parsetree_json with
            | Ok json -> Ast.of_json ~dialect:Parsetree ~filename json
            | Error msg -> raise (Analysis_error msg)));
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
                (Printf.sprintf "Failed to read file %s: %s" filename
                   (Printexc.to_string exn))));
  }

let create_project ~config ~project_root ~all_files ~dune_describe =
  let dune_desc_lazy = lazy dune_describe in
  {
    config;
    project_root;
    all_files = lazy all_files;
    dune_describe = dune_desc_lazy;
    executable_modules =
      lazy (Dune.get_executable_info (Lazy.force dune_desc_lazy));
    lib_modules = lazy (Dune.get_lib_modules (Lazy.force dune_desc_lazy));
    test_modules = lazy (Dune.get_test_modules (Lazy.force dune_desc_lazy));
  }

let filename = function
  | File ctx -> ctx.filename
  | Project _ -> failwith "No filename in project context"

let config = function File ctx -> ctx.config | Project ctx -> ctx.config

let project_root = function
  | File ctx -> ctx.project_root
  | Project ctx -> ctx.project_root

let browse = function
  | File ctx -> Lazy.force ctx.browse
  | Project _ -> failwith "No browse in project context"

let ast = function
  | File ctx -> Lazy.force ctx.ast
  | Project _ -> failwith "No ast in project context"

let outline = function
  | File ctx -> Lazy.force ctx.outline
  | Project _ -> failwith "No outline in project context"

let content = function
  | File ctx -> Lazy.force ctx.content
  | Project _ -> failwith "No content in project context"

let all_files = function
  | File _ -> failwith "No all_files in file context"
  | Project ctx -> Lazy.force ctx.all_files

let dune_describe = function
  | File _ -> failwith "No dune_describe in file context"
  | Project ctx -> Lazy.force ctx.dune_describe

let executable_modules = function
  | File _ -> failwith "No executable_modules in file context"
  | Project ctx -> Lazy.force ctx.executable_modules

let lib_modules = function
  | File _ -> failwith "No lib_modules in file context"
  | Project ctx -> Lazy.force ctx.lib_modules

let test_modules = function
  | File _ -> failwith "No test_modules in file context"
  | Project ctx -> Lazy.force ctx.test_modules
