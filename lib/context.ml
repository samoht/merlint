(** Context for rule checking - holds all parameters and data needed by rules *)

let src = Logs.Src.create "merlint.context" ~doc:"Context management"

module Log = (val Logs.src_log src : Logs.LOG)

exception Analysis_error = File_view.Analysis_error

let fail_analysis_error fmt = Fmt.kstr (fun s -> raise (Analysis_error s)) fmt

type 'a memo = { lock : Eio.Mutex.t; value : 'a Lazy.t }

let memo f = { lock = Eio.Mutex.create (); value = lazy (f ()) }
let memo_value value = memo (fun () -> value)

let force_memo memo =
  Eio.Mutex.lock memo.lock;
  Fun.protect
    ~finally:(fun () -> Eio.Mutex.unlock memo.lock)
    (fun () -> Lazy.force memo.value)

type file = {
  filename : string;
  config : Config.t;
  project_root : string;
  view : File_view.t;
  content : string Lazy.t;
}

type project = {
  config : Config.t;
  project_root : string;
  analyze_set : string list;
  dune_describe : Dune_describe.describe memo;
  executable_modules : string list memo;
  lib_modules : string list memo;
  test_modules : string list memo;
  index : Project_index.t memo;
  file_view_cache : string -> File_view.t;
  file_content_cache : string -> string;
}

let file ~filename ~config ~project_root ~load_content =
  {
    filename;
    config;
    project_root;
    view = File_view.v ~filename ~typedtree:(fun () -> Ok None) ();
    content = lazy (load_content ());
  }

let file_with_view ~filename ~config ~project_root ~view ~load_content =
  { filename; config; project_root; view; content = lazy (load_content ()) }

let default_load_content filename () =
  try In_channel.with_open_text filename In_channel.input_all
  with exn ->
    fail_analysis_error "Failed to read file %s: %s" filename
      (Printexc.to_string exn)

let default_file_view filename =
  File_view.v ~filename ~typedtree:(fun () -> Ok None) ()

let memoize_content make =
  let cache = Hashtbl.create 128 in
  let lock = Eio.Mutex.create () in
  fun filename ->
    let filename = Fpath.to_string (Fpath.normalize (Fpath.v filename)) in
    Eio.Mutex.lock lock;
    Fun.protect ~finally:(fun () -> Eio.Mutex.unlock lock) @@ fun () ->
    match Hashtbl.find_opt cache filename with
    | Some content -> content
    | None ->
        let content = make filename in
        Hashtbl.add cache filename content;
        content

let memoize_file_view make =
  let cache = Hashtbl.create 128 in
  let lock = Eio.Mutex.create () in
  fun filename ->
    let filename = Fpath.to_string (Fpath.normalize (Fpath.v filename)) in
    Eio.Mutex.lock lock;
    Fun.protect ~finally:(fun () -> Eio.Mutex.unlock lock) @@ fun () ->
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

let discover_test_modules ~index dune_desc =
  let dune_test_modules = Dune_describe.test_modules dune_desc in
  let file_test_modules =
    Project_index.source_files index
    |> List.filter_map (fun fp -> test_module_of_file (Fpath.to_string fp))
  in
  let all_test_modules =
    dune_test_modules @ file_test_modules |> List.sort_uniq String.compare
  in
  Log.debug (fun m ->
      m "Context: Total test modules: %d (dune: %d, files: %d)"
        (List.length all_test_modules)
        (List.length dune_test_modules)
        (List.length file_test_modules));
  all_test_modules

let project ?file_view ?file_content ~config ~project_root ~analyze_set
    ~dune_describe ~index () =
  let dune_desc_memo = memo_value dune_describe in
  let index_memo = memo (fun () -> Lazy.force index) in
  let file_view_cache =
    memoize_file_view (Option.value file_view ~default:default_file_view)
  in
  let file_content_cache =
    memoize_content
      (Option.value file_content ~default:(fun filename ->
           default_load_content filename ()))
  in
  {
    config;
    project_root;
    analyze_set;
    dune_describe = dune_desc_memo;
    executable_modules =
      memo (fun () ->
          Dune_describe.executable_modules (force_memo dune_desc_memo));
    lib_modules =
      memo (fun () -> Dune_describe.lib_modules (force_memo dune_desc_memo));
    test_modules =
      memo (fun () ->
          discover_test_modules ~index:(force_memo index_memo)
            (force_memo dune_desc_memo));
    index = index_memo;
    file_view_cache;
    file_content_cache;
  }

let index ctx = force_memo ctx.index

(* File context accessors *)
let view ctx = ctx.view
let content ctx = Lazy.force ctx.content
let values ctx = File_view.values ctx.view

(* Project context accessors *)
let analyze_set ctx = ctx.analyze_set
let project_root ctx = ctx.project_root
let executable_modules ctx = force_memo ctx.executable_modules
let lib_modules ctx = force_memo ctx.lib_modules
let test_modules ctx = force_memo ctx.test_modules
let dune_describe ctx = force_memo ctx.dune_describe
let file_view ctx filename = ctx.file_view_cache filename
let file_content ctx filename = ctx.file_content_cache filename
