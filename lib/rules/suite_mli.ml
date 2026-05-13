(** Shared helpers for rules that inspect [.mli] files which should expose
    exactly [val suite : <expected-type>] and nothing else. Used by E600
    (test_*.mli) and E705 (fuzz_*.mli). *)

let suite_val_re =
  Re.compile
    (Re.seq
       [
         Re.bow;
         Re.str "val";
         Re.rep1 Re.space;
         Re.str "suite";
         Re.rep Re.space;
         Re.str ":";
       ])

let any_val_re = Re.compile (Re.seq [ Re.bow; Re.str "val"; Re.rep1 Re.space ])
let whitespace_re = Re.compile (Re.rep1 Re.space)

(** Drop blank lines and lines that look like the start of a comment block.
    Leaves the rest verbatim so downstream regexen still see column 0. *)
let non_comment_lines content =
  content |> String.split_on_char '\n'
  |> List.filter (fun line ->
      let trimmed = String.trim line in
      trimmed <> "" && not (String.starts_with ~prefix:"(*" trimmed))

(** Find the line that declares [val suite : ...], if any. *)
let suite_line lines = List.find_opt (Re.execp suite_val_re) lines

(** Whether [lines] export at least one [val foo : ...] declaration that is not
    [val suite : ...]. *)
let exports_non_suite_val lines =
  List.exists
    (fun line -> Re.execp any_val_re line && not (Re.execp suite_val_re line))
    lines

(** [matches_suite_type ~expected line] is [true] iff [line] (the
    [val suite : ...] line) ends with [expected] after whitespace normalisation.
*)
let matches_suite_type ~expected line =
  let normalized =
    Re.replace_string whitespace_re ~by:" " line |> String.trim
  in
  String.ends_with ~suffix:expected normalized

(** [is_compliant ~expected content] is [true] when the [.mli]'s significant
    lines all check out: exactly one [val suite] of the right type and no other
    [val ...] exports. *)
let is_compliant ~expected content =
  let lines = non_comment_lines content in
  match suite_line lines with
  | None -> false
  | Some line ->
      matches_suite_type ~expected line && not (exports_non_suite_val lines)
