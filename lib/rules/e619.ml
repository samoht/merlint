(** E619: Test Suite Never Run *)

type payload = { module_ : string; library : string }

let log_src = Logs.Src.create "merlint.rules.e619" ~doc:"E619 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

(* Which source files can name a library's suites. A [suite] is defined in one
   file and invoked from another, so the question this rule answers is not a
   property of the defining file: it is answered by the files of every stanza
   that links the defining file's library, and by the library's own files. The
   edges come from the [(libraries ...)] fields the index already parsed, so
   nothing here re-reads a dune file.

   Two things this does not see, both measured on 2026-08-30 and both visible
   in the [-vv] trace rather than silently absent:

   - a module whose [suite] is a list of suites ([let suite = [ (name, cases) ]])
     rather than one [(name, cases)] pair. {!Suite.bindings} recognises the pair
     alone, and E621 and E725 read the same binding for its name and emptiness,
     so widening it is their change too. [ocaml-hash/test/backend] and
     [ocaml-crypto/test/backend] are written that way.
   - a library {!Project.Query.source_libraries} does not report. It walks the
     packages' library lists, and a private library the index attributes to no
     package is absent from them: [fsm_trace_target] and [crypto_backend_tests]
     are, though each is named in a [(libraries ...)] field of a stanza that
     does carry a package. *)
type env = {
  own : (string, Fpath.t list) Hashtbl.t;
      (** Local library name -> its own [.ml] files. *)
  dependents : (string, Fpath.t list) Hashtbl.t;
      (** Local library name -> the [.ml] files of everything that links it. *)
}

let ml_files files =
  List.filter (fun f -> File_kind.is_ml (Fpath.to_string f)) files

let add table ~key files =
  match files with
  | [] -> ()
  | files ->
      let previous = Option.value ~default:[] (Hashtbl.find_opt table key) in
      Hashtbl.replace table key (List.rev_append files previous)

let record_edges index env ~libraries files =
  let files = ml_files files in
  List.iter
    (fun dep ->
      add env.dependents ~key:(Project.Query.resolve_library index dep) files)
    libraries

let record_library index env lib =
  let name = Project_index.Library.local_name lib in
  add env.own ~key:name (ml_files (Project_index.Library.files lib));
  record_edges index env
    ~libraries:(Project_index.Library.deps lib)
    (Project_index.Library.files lib)

let record_stanza index env (stanza : Project_index.source_stanza) =
  record_edges index env ~libraries:stanza.libraries stanza.files

let selected ctx file =
  try ctx.Context.in_analyze_set (Context.resolve ctx file)
  with Invalid_argument _ -> false

let log_candidate lib ~files ~selected_files candidate =
  Log.debug (fun m ->
      m "E619: %s candidate=%b public=%a gated=%b files=%d selected=%d"
        (Project_index.Library.local_name lib)
        candidate
        Fmt.(Dump.option string)
        (Project_index.Library.public_name lib)
        (Project_index.Library.gated lib)
        (List.length files)
        (List.length selected_files))

(* A private library is visible only inside its own dune project, so every
   stanza that can link it is one the scan either read or did not reach -- and
   the empty-dependents case below tells those two apart. A public library can
   be linked by a tree this run never sees, so no absence claim about its
   suites is available here at all. *)
let is_candidate ctx lib =
  let files = ml_files (Project_index.Library.files lib) in
  let selected_files = List.filter (selected ctx) files in
  let candidate =
    Project_index.Library.public_name lib = None
    && (not (Project_index.Library.gated lib))
    && (not (Project_index.Library.is_vendored lib))
    && selected_files <> []
  in
  log_candidate lib ~files ~selected_files candidate;
  candidate

let enumerate ctx =
  let index = Context.index ctx in
  let libs = Project.Query.source_libraries index in
  match List.filter (is_candidate ctx) libs with
  | [] -> []
  | candidates ->
      let env = { own = Hashtbl.create 64; dependents = Hashtbl.create 64 } in
      List.iter (record_library index env) libs;
      List.iter (record_stanza index env)
        (Context.test_stanzas ctx @ Context.executable_stanzas ctx);
      List.map (fun lib -> (env, lib)) candidates

(* The suites this library defines, as (module name, binding location), for the
   files the run was asked about. *)
let definition ctx index file =
  let path = Context.resolve ctx file in
  let filename = Context.string_of_path path in
  match Suite.bindings ~filename (Context.file_view ctx path) with
  | [] -> None
  | (binding : Suite.binding) :: _ ->
      let module_ =
        String.capitalize_ascii (Project_index.module_name_of_file index file)
      in
      Some (module_, binding.loc)

let definitions ctx index lib =
  ml_files (Project_index.Library.files lib)
  |> List.filter (selected ctx)
  |> List.filter_map (fun file ->
      try definition ctx index file with File_view.Analysis_error _ -> None)

(* An unbuilt consumer answers no absence claim: its typedtree carries no
   identifiers, so every suite would read as unreferenced. One such file
   retires the whole library's answer rather than shrinking it. *)
type resolution = Unresolved | Callers of Suite.callers list

let add_caller ctx acc file =
  match acc with
  | Unresolved -> Unresolved
  | Callers callers -> (
      let view = Context.file_view ctx (Context.resolve ctx file) in
      match Suite.callers view with
      | None -> Unresolved
      | Some c -> Callers (c :: callers))

let consumer_callers ctx files =
  try List.fold_left (add_caller ctx) (Callers []) files
  with File_view.Analysis_error _ -> Unresolved

let undecided ctx ~library reason =
  Context.cannot_evaluate ctx ~rule:"E619"
    (Fmt.str "whether library %s's test suites are ever run: %s" library reason)

let issue ~library callers (module_, loc) =
  if List.exists (fun c -> Suite.references_in c module_) callers then None
  else Some (Issue.v ~loc { module_; library })

let files_of table key = Option.value ~default:[] (Hashtbl.find_opt table key)

let check_defined ctx env ~library defs =
  match files_of env.dependents library with
  | [] ->
      undecided ctx ~library "nothing this scan read links it";
      []
  | dependents -> (
      match consumer_callers ctx (files_of env.own library @ dependents) with
      | Unresolved ->
          undecided ctx ~library "a file that could reference them is not built";
          []
      | Callers callers -> List.filter_map (issue ~library callers) defs)

let check ctx (env, lib) =
  let library = Project_index.Library.local_name lib in
  let defs = definitions ctx (Context.index ctx) lib in
  Log.debug (fun m ->
      m "E619: library %s defines %d suite(s) %a, %d file(s) link it" library
        (List.length defs)
        Fmt.(Dump.list string)
        (List.map fst defs)
        (List.length (files_of env.dependents library)));
  match defs with [] -> [] | defs -> check_defined ctx env ~library defs

let pp ppf { module_; library } =
  Fmt.pf ppf
    "Test suite %s.suite is never run: nothing linking library %s references it"
    module_ library

let rule =
  Rule.v ~code:"E619" ~title:"Test Suite Never Run" ~category:Testing
    ~hint:
      "A test module in a library exports a 'suite' that no runner names. The \
       alias over its directory then passes without running one of its cases, \
       which reads exactly like a directory whose tests all pass. Name the \
       suite in the runner that links the library, or delete the module."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
