(** E710: Fuzz Without Library *)

type payload = { fuzz_file : string; expected_module : string }

(** Extract the expected library module name from a fuzz file. fuzz_foo.ml ->
    foo *)
let expected_lib_module fuzz_file =
  let basename = Fpath.(fuzz_file |> rem_ext |> basename) in
  if String.starts_with ~prefix:"fuzz_" basename then
    Some (String.sub basename 5 (String.length basename - 5))
  else None

let words name = String.split_on_char '_' (String.lowercase_ascii name)

let rec is_subsequence xs ys =
  match (xs, ys) with
  | [], _ -> true
  | _, [] -> false
  | x :: xs', y :: ys' ->
      if String.equal x y then is_subsequence xs' ys' else is_subsequence xs ys'

(* [fuzz_X.ml] names what it fuzzes the way the directory around it reads it,
   which is with the package's own word left off one side or supplied on the
   other: [fuzz_diagram.ml] under [ocaml-fsm/] fuzzes library [fsm-diagram],
   whose entry module is [Fsm_diagram]; [fuzz_eio.ml] under [ocaml-ssh/] fuzzes
   [ssh-eio], whose entry module is [Ssh_eio]; [fuzz_oci_store.ml] under
   [ocaml-oci/] fuzzes [Store] of [oci-layer.server]. In each the two names
   carry the same words in the same order, one of them spelling out a word the
   other leaves to the surrounding package, so the relation to check is that the
   shorter word list runs through the longer. *)
let names_match a b =
  let a = words a and b = words b in
  is_subsequence a b || is_subsequence b a

(* The names the stanza's own libraries answer to: each library's local name --
   which is its entry module, lowercased -- and each module it exposes.
   Resolution goes through the package the stanza belongs to, so a private
   helper library, which is most of what a fuzz directory links, counts, and an
   unrelated package's library of the same name does not. *)
let stanza_library_names index (s : Project_index.source_stanza) =
  match Project_index.package index s.package with
  | None -> []
  | Some pkg ->
      Project_index.libraries_used_by pkg s.libraries
      |> List.concat_map (fun lib ->
          Project_index.Library.local_name lib
          :: Project_index.Library.modules lib)

let fuzz_files_of_stanza (s : Project_index.source_stanza) =
  List.filter_map
    (fun f ->
      if Fpath.has_ext ".ml" f && File.is_in_fuzz_dir f then
        Option.map (fun expected -> (s, f, expected)) (expected_lib_module f)
      else None)
    s.files

let check (ctx : Context.project) =
  let index = Context.index ctx in
  let lib_modules = Context.lib_modules ctx in
  let fuzz_files =
    List.concat_map fuzz_files_of_stanza
      (Context.test_stanzas ctx @ Context.executable_stanzas ctx)
  in
  List.filter_map
    (fun (stanza, file, expected) ->
      let found =
        List.exists
          (fun lib_mod ->
            String.lowercase_ascii lib_mod = String.lowercase_ascii expected)
          lib_modules
        || List.exists (names_match expected)
             (stanza_library_names index stanza)
      in
      if found then None
      else
        let loc =
          Location.v ~file:(Fpath.to_string file) ~start_line:1 ~start_col:0
            ~end_line:1 ~end_col:0
        in
        Some
          (Issue.v ~loc
             { fuzz_file = Fpath.to_string file; expected_module = expected }))
    fuzz_files

let pp ppf { fuzz_file = _; expected_module } =
  Fmt.pf ppf "Fuzz file exists but corresponding library module '%s' not found"
    expected_module

let rule =
  Rule.v ~code:"E710" ~title:"Fuzz Without Library" ~category:Testing
    ~hint:
      "Every fuzz module (fuzz_<module>.ml) should name what it fuzzes: a \
       module of a library, or a library its own stanza links, whose name \
       carries the same words in the same order (fuzz_diagram.ml for \
       fsm-diagram's Fsm_diagram). This ensures fuzz tests are testing actual \
       library functionality."
    ~examples:[] ~pp (Project check)
