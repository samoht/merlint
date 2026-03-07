(** E618: Non-Test File in Test Stanza *)

type payload = { filename : string; test_stanza : string }

(** Allowed basenames in test stanzas that don't need the test_ prefix. *)
let is_allowed_name basename = basename = "test" || basename = "test_helpers"

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  List.concat_map
    (fun (test_info : Dune.test_info) ->
      List.filter_map
        (fun file ->
          if Fpath.has_ext ".ml" file then
            let basename = Fpath.(file |> rem_ext |> basename) in
            if
              not
                (String.starts_with ~prefix:"test_" basename
                || is_allowed_name basename)
            then
              let loc =
                Location.v ~file:(Fpath.to_string file) ~start_line:1
                  ~start_col:0 ~end_line:1 ~end_col:0
              in
              Some
                (Issue.v ~loc
                   {
                     filename = Fpath.to_string file;
                     test_stanza = test_info.Dune.name;
                   })
            else None
          else None)
        test_info.Dune.files)
    (Dune.tests dune_describe)

let pp ppf { filename; test_stanza } =
  Fmt.pf ppf
    "File '%s' in test stanza '%s' does not follow the test_ naming convention \
     - extract into a private (library ...) stanza"
    (Filename.basename filename)
    test_stanza

let rule =
  Rule.v ~code:"E618" ~title:"Non-Test File in Test Stanza" ~category:Testing
    ~hint:
      "All .ml files in a test stanza should follow the test_ naming \
       convention (e.g., test_parser.ml) or be the test runner (test.ml). \
       Helper modules should be extracted into a private (library ...) stanza \
       in a subdirectory."
    ~examples:[] ~pp (Project check)
