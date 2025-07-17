(** Context for rule checking - holds all parameters and data needed by rules *)

exception Analysis_error of string

type file = {
  filename : string;
  config : Config.t;
  project_root : string;
  ast : Ast.t Lazy.t;
  outline : Outline.t Lazy.t;
  content : string Lazy.t;
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

let create_file ~filename ~config ~project_root ~merlin_result =
  {
    filename;
    config;
    project_root;
    ast =
      lazy
        (match merlin_result.Merlin.dump with
        | Ok ast -> ast
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

(* File context accessors *)
let ast ctx = Lazy.force ctx.ast
let outline ctx = Lazy.force ctx.outline
let content ctx = Lazy.force ctx.content

(* Project context accessors *)
let all_files ctx = Lazy.force ctx.all_files
let executable_modules ctx = Lazy.force ctx.executable_modules
let lib_modules ctx = Lazy.force ctx.lib_modules
let test_modules ctx = Lazy.force ctx.test_modules
