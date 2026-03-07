(** E618: Non-Test File in Test Stanza *)

type payload = { filename : string; test_stanza : string; prefix : string }

(** Guess the expected prefix from the directory name. *)
let prefix_of_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  if String.equal dir "fuzz" then "fuzz_" else "test_"

let is_valid basename ~prefix =
  String.starts_with ~prefix basename || String.equal basename "test"

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  List.concat_map
    (fun (test_info : Dune.test_info) ->
      List.filter_map
        (fun file ->
          if Fpath.has_ext ".ml" file then
            let basename = Fpath.(file |> rem_ext |> basename) in
            let prefix = prefix_of_dir file in
            if not (is_valid basename ~prefix) then
              let loc =
                Location.v ~file:(Fpath.to_string file) ~start_line:1
                  ~start_col:0 ~end_line:1 ~end_col:0
              in
              Some
                (Issue.v ~loc
                   {
                     filename = Fpath.to_string file;
                     test_stanza = test_info.Dune.name;
                     prefix;
                   })
            else None
          else None)
        test_info.Dune.files)
    (Dune.tests dune_describe)

let pp ppf { filename; test_stanza; prefix } =
  let basename = Filename.basename filename in
  let modname = Filename.chop_extension basename in
  Fmt.pf ppf
    "File '%s' in test stanza '%s' does not follow the %s naming convention - \
     extract into a private (library ...) stanza or rename to %s%s.ml"
    basename test_stanza prefix prefix modname

let rule =
  Rule.v ~code:"E618" ~title:"Non-Test File in Test Stanza" ~category:Testing
    ~hint:
      "All .ml files in a test stanza should follow the test_ (or fuzz_ in \
       fuzz/ directories) naming convention or be the test runner (test.ml). \
       Non-test modules should either be extracted into a private (library \
       ...) stanza or renamed to <prefix>_<module>.ml."
    ~examples:[] ~pp (Project check)
