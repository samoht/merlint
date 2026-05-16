(** Context for rule checking - holds all parameters and data needed by rules *)

let src = Logs.Src.create "merlint.context" ~doc:"Context management"

module Log = (val Logs.src_log src : Logs.LOG)

exception Analysis_error = File_view.Analysis_error

let fail_analysis_error fmt = Fmt.kstr (fun s -> raise (Analysis_error s)) fmt

type file = {
  filename : string;
  config : Config.t;
  project_root : string;
  view : File_view.t;
}

type project = {
  config : Config.t;
  project_root : string;
  all_files : string list Lazy.t;
  dune_describe : Dune_describe.describe Lazy.t;
  executable_modules : string list Lazy.t;
  lib_modules : string list Lazy.t;
  test_modules : string list Lazy.t;
  index : Project_index.t Lazy.t;
  file_view_cache : string -> File_view.t;
}

let file ~filename ~config ~project_root ~load_content ~outline =
  {
    filename;
    config;
    project_root;
    view = File_view.v ~filename ~load_content ~outline ();
  }

let file_with_view ~filename ~config ~project_root ~view =
  { filename; config; project_root; view }

let default_load_content filename () =
  try In_channel.with_open_text filename In_channel.input_all
  with exn ->
    fail_analysis_error "Failed to read file %s: %s" filename
      (Printexc.to_string exn)

let default_file_view filename =
  File_view.v ~filename
    ~load_content:(default_load_content filename)
    ~outline:(fun () -> Error "Merlin outline unavailable in this context")
    ()

let memoize_file_view make =
  let cache = Hashtbl.create 128 in
  fun filename ->
    let filename = Fpath.to_string (Fpath.normalize (Fpath.v filename)) in
    match Hashtbl.find_opt cache filename with
    | Some view -> view
    | None ->
        let view = make filename in
        Hashtbl.add cache filename view;
        view

let test_module_of_file f =
  if File_kind.is_ml f then
    let basename = Filename.basename f |> Filename.remove_extension in
    if String.starts_with ~prefix:"test_" basename || basename = "test" then begin
      Log.debug (fun m ->
          m "Context: Found test file %s -> module %s" f basename);
      Some basename
    end
    else None
  else None

let discover_test_modules ~all_files dune_desc_lazy =
  (* Get test modules from dune describe *)
  let dune_test_modules =
    Dune_describe.test_modules (Lazy.force dune_desc_lazy)
  in
  (* Also discover test_*.ml files from all_files that might not be in dune *)
  let file_test_modules = List.filter_map test_module_of_file all_files in
  (* Combine and deduplicate *)
  let all_test_modules =
    dune_test_modules @ file_test_modules |> List.sort_uniq String.compare
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
  all_test_modules

let project ?file_view ~config ~project_root ~all_files ~dune_describe ~index ()
    =
  let dune_desc_lazy = lazy dune_describe in
  let file_view_cache =
    memoize_file_view (Option.value file_view ~default:default_file_view)
  in
  {
    config;
    project_root;
    all_files =
      lazy
        (Log.debug (fun m ->
             m "Context: Total files to analyze: %d" (List.length all_files));
         all_files);
    dune_describe = dune_desc_lazy;
    executable_modules =
      lazy (Dune_describe.executable_modules (Lazy.force dune_desc_lazy));
    lib_modules = lazy (Dune_describe.lib_modules (Lazy.force dune_desc_lazy));
    test_modules = lazy (discover_test_modules ~all_files dune_desc_lazy);
    index;
    file_view_cache;
  }

let index ctx = Lazy.force ctx.index

(* File context accessors *)
let view ctx = ctx.view
let ast ctx = File_view.ast ctx.view
let outline ctx = File_view.outline ctx.view
let content ctx = File_view.content ctx.view
let functions ctx = File_view.functions ctx.view

(* Project context accessors *)
let all_files ctx = Lazy.force ctx.all_files
let executable_modules ctx = Lazy.force ctx.executable_modules
let lib_modules ctx = Lazy.force ctx.lib_modules
let test_modules ctx = Lazy.force ctx.test_modules
let dune_describe ctx = Lazy.force ctx.dune_describe
let file_view ctx filename = ctx.file_view_cache filename
