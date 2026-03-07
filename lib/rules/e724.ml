(** E724: Missing Fuzz Build Rules *)

type payload = { directory : string; missing : [ `runtest | `fuzz | `both ] }

let is_fuzz_dir file =
  let dir = Fpath.parent file |> Fpath.basename in
  String.equal dir "fuzz"

(** Collect fuzz directories from executable stanzas. *)
let fuzz_dirs dune_describe =
  let dirs =
    List.filter_map
      (fun (name, files) ->
        if not (String.starts_with ~prefix:"fuzz" name) then None
        else
          match
            List.find_opt
              (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f)
              files
          with
          | Some f -> Some (Fpath.parent f |> Fpath.to_string)
          | None -> None)
      (Dune.executables dune_describe)
  in
  List.sort_uniq String.compare dirs

(** Check that fuzz dune files contain required rule aliases. *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let dirs = fuzz_dirs dune_describe in
  List.filter_map
    (fun dir ->
      let dune_file = Filename.concat dir "dune" in
      try
        let content =
          In_channel.with_open_text dune_file In_channel.input_all
        in
        let has_runtest =
          Re.execp (Re.compile (Re.str "(alias runtest)")) content
        in
        let has_fuzz = Re.execp (Re.compile (Re.str "(alias fuzz)")) content in
        let missing =
          match (has_runtest, has_fuzz) with
          | true, true -> None
          | false, false -> Some `both
          | false, true -> Some `runtest
          | true, false -> Some `fuzz
        in
        match missing with
        | None -> None
        | Some missing ->
            let loc =
              Location.v ~file:dune_file ~start_line:1 ~start_col:0 ~end_line:1
                ~end_col:0
            in
            Some (Issue.v ~loc { directory = dir; missing })
      with _ -> None)
    dirs

let pp ppf { directory; missing } =
  match missing with
  | `runtest ->
      Fmt.pf ppf
        "Fuzz directory '%s' is missing (rule (alias runtest) ...) for \
         property-based testing"
        directory
  | `fuzz ->
      Fmt.pf ppf
        "Fuzz directory '%s' is missing (rule (alias fuzz) ...) for AFL \
         campaigns"
        directory
  | `both ->
      Fmt.pf ppf
        "Fuzz directory '%s' is missing both (rule (alias runtest) ...) and \
         (rule (alias fuzz) ...) build rules"
        directory

let rule =
  Rule.v ~code:"E724" ~title:"Missing Fuzz Build Rules" ~category:Testing
    ~hint:
      "Each fuzz directory should have (rule (alias runtest) ...) for \
       property-based testing during dune test, and (rule (alias fuzz) ...) \
       for AFL fuzzing campaigns with corpus generation."
    ~examples:[] ~pp (Project check)
