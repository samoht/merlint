(** Linting engine. *)

type exclusion_stats = { rule : string; file : string }
(** A single suppressed issue. *)

type result = { issues : Rule.Run.result list; excluded : exclusion_stats list }
(** Analysis result. *)

val run :
  load_file:(string -> string) ->
  filter:Filter.t ->
  dune_describe:Dune_describe.describe ->
  ?files_to_analyze:Fpath.t list ->
  index:Project_index.t Lazy.t ->
  ?profiling:Profiling.t ->
  string ->
  result
(** [run ~load_file ~filter ~dune_describe ?files_to_analyze ~index ?profiling
     project_root] runs all checks. Returns detected issues and a record of
    every suppressed issue.

    [load_file] reads a file's content. The CLI plumbs an Eio-backed reader so
    file I/O goes through {!Eio.Path.load}; tests pass a stdlib reader.

    [dune_describe] is the project-wide view used by project-scoped rules: E605
    (Missing Test File), E610 (Test Without Library), E606 (Test File in Wrong
    Directory), E615 (Test Suite Not Included), E620 (Multiple Test Stanzas),
    etc. It must reflect the whole project even when [merlint] is invoked on a
    single file, otherwise project rules fire false positives or fail silently.

    [files_to_analyze] narrows what {b file}-scoped rules iterate. Defaults to
    every file in [dune_describe]. The CLI passes the explicit file list here in
    single-file mode so file-scoped rules don't widen to the whole project while
    project-scoped rules still see the full library/test view.

    [index] is forced lazily when a rule reads it. *)
