(** E722: Fuzz Uses Test Stanza *)

type payload = { stanza_name : string; directory : string }

let is_fuzz_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  String.equal dir "fuzz"

(** Find test stanzas that contain files in fuzz/ directories. These should use
    (executable ...) stanzas instead. *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  List.filter_map
    (fun (t : Dune.test_info) ->
      let fuzz_files =
        List.filter (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f) t.files
      in
      match fuzz_files with
      | [] -> None
      | file :: _ ->
          let dir = Fpath.parent file |> Fpath.to_string in
          let loc =
            Location.v
              ~file:(Filename.concat dir "dune")
              ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
          in
          Some (Issue.v ~loc { stanza_name = t.name; directory = dir }))
    (Dune.tests dune_describe)

let pp ppf { stanza_name; directory = _ } =
  Fmt.pf ppf
    "Fuzz stanza '%s' uses (test ...) - use (executable ...) with (rule (alias \
     runtest) ...) instead"
    stanza_name

let rule =
  Rule.v ~code:"E722" ~title:"Fuzz Uses Test Stanza" ~category:Testing
    ~hint:
      "Fuzz targets should use (executable ...) stanzas with explicit (rule \
       (alias runtest) ...) and (rule (alias fuzz) ...) rules, not (test ...) \
       stanzas. This enables property-based testing during dune test and \
       separate AFL campaign workflows."
    ~examples:[] ~pp (Project check)
