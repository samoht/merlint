(** Context for rule checking - holds all parameters and data needed by rules *)

let src = Logs.Src.create "merlint.context" ~doc:"Context management"

module Log = (val Logs.src_log src : Logs.LOG)

exception Analysis_error = File_view.Analysis_error

let fail_analysis_error fmt = Fmt.kstr (fun s -> raise (Analysis_error s)) fmt

type path = Fpath.t

let normalize_path path = Fpath.(path |> normalize |> rem_empty_seg)
let path s = normalize_path (Fpath.v s)
let fpath_of_path p = p
let string_of_path = Fpath.to_string

let relative_to ~root p =
  match Fpath.relativize ~root p with Some rel -> rel | None -> p

module Path = struct
  let v = path

  let ( / ) p child =
    let child = Fpath.v child in
    if Fpath.is_abs child then
      Fmt.invalid_arg "merlint: cannot append absolute child path %a" Fpath.pp
        child;
    normalize_path Fpath.(p // child)

  let compare = Fpath.compare
  let pp ppf p = Fmt.string ppf (Fpath.to_string p)
  let to_display_string p = Loc.current_dir_relative p |> Fpath.to_string

  let dir_display_string p =
    Loc.current_dir_relative p |> Fpath.to_dir_path |> Fpath.to_string

  let has_ext ext p = Fpath.has_ext ext p
  let basename = Fpath.basename
  let parent p = normalize_path (Fpath.parent p)
  let rem_ext p = normalize_path (Fpath.rem_ext p)
  let add_ext ext p = normalize_path (Fpath.add_ext ext p)
end

let path_is_under ~root path =
  Fpath.equal root path || Fpath.is_prefix root path
  ||
  (* [Fpath.is_prefix] is a textual segment check, so a "." root is not a
     prefix of a relative path like "bottler/x.ml" even though that path is
     under it. Fall back to relativizing: a path is under [root] when it
     relativizes without an initial ".." segment escaping above the root. *)
  match Fpath.relativize ~root path with
  | Some rel -> ( match Fpath.segs rel with ".." :: _ -> false | _ -> true)
  | None -> false

let path_under ~root s =
  let p = Fpath.v s in
  let p = if Fpath.is_abs p then p else Fpath.(root // p) in
  let p = normalize_path p in
  if not (path_is_under ~root p) then
    Fmt.invalid_arg "merlint: source path %S escapes project root %S" s
      (Fpath.to_string root);
  p

type 'a memo = { lock : Eio.Mutex.t; value : 'a Lazy.t }

let memo f = { lock = Eio.Mutex.create (); value = lazy (f ()) }

let force_memo memo =
  Eio.Mutex.lock memo.lock;
  Fun.protect
    ~finally:(fun () -> Eio.Mutex.unlock memo.lock)
    (fun () -> Lazy.force memo.value)

type file = {
  filename : path;
  config : Config.t;
  project_root : path;
  analyze_set : path list;
  selected_file : path -> bool;
  project_index : Project_index.t option;
  view : File_view.t;
  content : string Lazy.t;
}

type project = {
  config : Config.t;
  project_root : path;
  analyze_set : path list;
  in_analyze_set : path -> bool;
  executable_modules : string list memo;
  lib_modules : string list memo;
  test_modules : string list memo;
  index : Project_index.t memo;
  file_view_cache : path -> File_view.t;
  file_content_cache : path -> string;
}

let file ~analyze_set ~selected_file ~project_index ~filename ~config
    ~project_root ~load_content =
  {
    filename;
    config;
    project_root;
    analyze_set;
    selected_file;
    project_index;
    view =
      File_view.v ~filename:(string_of_path filename)
        ~typedtree:(fun () -> Ok None)
        ();
    content = lazy (load_content ());
  }

let file_with_view ~analyze_set ~selected_file ~project_index ~filename ~config
    ~project_root ~view ~load_content =
  {
    filename;
    config;
    project_root;
    analyze_set;
    selected_file;
    project_index;
    view;
    content = lazy (load_content ());
  }

let default_load_content filename () =
  try In_channel.with_open_text filename In_channel.input_all
  with exn ->
    fail_analysis_error "Failed to read file %s: %s" filename
      (Printexc.to_string exn)

let default_file_view filename =
  File_view.v ~filename ~typedtree:(fun () -> Ok None) ()

(* Memoise [make] keyed by file path. The lock guards only the cache table, not
   [make] itself: [make] reads (and parses) a file, and holding the lock across
   that I/O serialised every reader across the executor pool's domains. Two
   domains racing on the same fresh key may both run [make] -- wasteful but
   rare and harmless, since the result is value-equal. *)
let memoize_content make =
  let cache = Hashtbl.create 128 in
  let lock = Eio.Mutex.create () in
  let find key = Eio.Mutex.use_ro lock (fun () -> Hashtbl.find_opt cache key) in
  let store key v =
    Eio.Mutex.use_rw ~protect:false lock (fun () -> Hashtbl.replace cache key v)
  in
  fun filename ->
    let key = string_of_path filename in
    match find key with
    | Some content -> content
    | None ->
        let content = make filename in
        store key content;
        content

let memoize_file_view make =
  let cache = Hashtbl.create 128 in
  let lock = Eio.Mutex.create () in
  let find key = Eio.Mutex.use_ro lock (fun () -> Hashtbl.find_opt cache key) in
  let store key v =
    Eio.Mutex.use_rw ~protect:false lock (fun () -> Hashtbl.replace cache key v)
  in
  fun filename ->
    let key = string_of_path filename in
    match find key with
    | Some view -> view
    | None ->
        let view = make filename in
        store key view;
        view

let resolve (ctx : project) filename =
  path_under ~root:ctx.project_root (Fpath.to_string filename)

let resolve_path ctx filename = string_of_path (resolve ctx filename)

let resolve_file (ctx : file) filename =
  path_under ~root:ctx.project_root (Fpath.to_string filename)

let resolve_file_path ctx filename = string_of_path (resolve_file ctx filename)

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

let source_packages index = Project_index.source_package_list index

let source_libraries index =
  source_packages index |> List.concat_map Project_index.package_libraries

let ml_module_name file =
  let s = Fpath.to_string file in
  if File_kind.is_ml s then Some Fpath.(file |> rem_ext |> basename) else None

let discover_executable_modules ~index =
  source_packages index
  |> List.concat_map Project_index.Package.executable_modules
  |> List.sort_uniq String.compare

let discover_lib_modules ~index =
  let public_libs =
    source_libraries index
    |> List.filter (fun lib ->
        Option.is_some (Project_index.Library.public_name lib))
  in
  let lib_names = List.map Project_index.Library.local_name public_libs in
  let file_modules =
    public_libs
    |> List.concat_map Project_index.Library.files
    |> List.filter_map ml_module_name
  in
  lib_names @ file_modules |> List.sort_uniq String.compare

let discover_test_modules ~index =
  let dune_test_modules =
    source_packages index
    |> List.concat_map Project_index.Package.test_modules
    |> List.sort_uniq String.compare
  in
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

let discover_executable_stanzas ~index =
  source_packages index
  |> List.concat_map Project_index.Package.executable_stanzas
  |> List.sort_uniq compare

let discover_test_stanzas ~index =
  source_packages index
  |> List.concat_map Project_index.Package.test_stanzas
  |> List.sort_uniq compare

let project ?file_view ?file_content ~config ~project_root ~analyze_set ~index
    () =
  let index_memo = memo (fun () -> Lazy.force index) in
  let analyze_set_tbl = Hashtbl.create (List.length analyze_set) in
  let add_analyze_file file =
    if not (Fpath.is_abs file) then
      Fmt.invalid_arg "merlint: analyze_set path %S is not absolute"
        (Fpath.to_string file);
    Hashtbl.replace analyze_set_tbl file ()
  in
  List.iter add_analyze_file analyze_set;
  let in_analyze_set file = Hashtbl.mem analyze_set_tbl file in
  let file_view_cache =
    let make =
      Option.value file_view ~default:(fun filename ->
          default_file_view (string_of_path filename))
    in
    memoize_file_view make
  in
  let file_content_cache =
    memoize_content (fun filename ->
        match file_content with
        | Some make -> make filename
        | None -> default_load_content (string_of_path filename) ())
  in
  {
    config;
    project_root;
    analyze_set;
    in_analyze_set;
    executable_modules =
      memo (fun () ->
          discover_executable_modules ~index:(force_memo index_memo));
    lib_modules =
      memo (fun () -> discover_lib_modules ~index:(force_memo index_memo));
    test_modules =
      memo (fun () -> discover_test_modules ~index:(force_memo index_memo));
    index = index_memo;
    file_view_cache;
    file_content_cache;
  }

let index ctx = force_memo ctx.index

(* File context accessors *)
let view ctx = ctx.view
let content ctx = Lazy.force ctx.content
let values ctx = File_view.values ctx.view
let file_path ctx = ctx.filename
let filename ctx = string_of_path ctx.filename
let project_root_string (ctx : file) = string_of_path ctx.project_root

let project_relative_file (ctx : file) =
  relative_to ~root:ctx.project_root ctx.filename

(* Project context accessors *)
let analyze_set ctx = ctx.analyze_set
let project_root ctx = ctx.project_root
let project_root_path (ctx : project) = string_of_path ctx.project_root

let project_relative_path (ctx : project) path =
  relative_to ~root:ctx.project_root path

let executable_modules ctx = force_memo ctx.executable_modules
let lib_modules ctx = force_memo ctx.lib_modules
let test_modules ctx = force_memo ctx.test_modules
let executable_stanzas ctx = discover_executable_stanzas ~index:(index ctx)
let test_stanzas ctx = discover_test_stanzas ~index:(index ctx)
let file_view ctx filename = ctx.file_view_cache filename
let file_content ctx filename = ctx.file_content_cache filename
