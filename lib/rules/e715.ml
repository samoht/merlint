(** E715: Fuzz Module Not Included *)

type payload = { fuzz_module : string; fuzz_runner_file : string }

let is_fuzz_dir = File.is_in_fuzz_dir

(** Check if fuzz.ml includes all fuzz modules via Fuzz_*.suite *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let issues = ref [] in
  let check_stanza stanza_name files =
    let fuzz_files =
      List.filter (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f) files
    in
    (* Find fuzz.ml runner *)
    let fuzz_ml =
      List.find_opt
        (fun f -> Fpath.(f |> rem_ext |> basename) = "fuzz")
        fuzz_files
    in
    match fuzz_ml with
    | None -> () (* No fuzz.ml, E718 will flag this *)
    | Some runner_file -> (
        try
          let content =
            In_channel.with_open_text
              (Fpath.to_string runner_file)
              In_channel.input_all
          in
          (* Remove comments *)
          let content =
            Re.replace_string
              (Re.compile
                 (Re.seq
                    [ Re.str "(*"; Re.non_greedy (Re.rep Re.any); Re.str "*)" ]))
              ~by:"" content
          in
          (* Find fuzz modules in this stanza *)
          let fuzz_modules =
            List.filter_map
              (fun f ->
                if f <> runner_file then
                  let basename = Fpath.(f |> rem_ext |> basename) in
                  if
                    String.starts_with ~prefix:"fuzz_" basename
                    && basename <> "fuzz_common"
                  then Some basename
                  else None
                else None)
              fuzz_files
          in
          Logs.debug (fun m ->
              m "E715: stanza '%s' has %d fuzz modules" stanza_name
                (List.length fuzz_modules));
          (* Check which fuzz modules are not included in fuzz.ml *)
          List.iter
            (fun fuzz_mod ->
              let capitalized = String.capitalize_ascii fuzz_mod in
              let run_pattern =
                Re.compile
                  (Re.seq [ Re.bow; Re.str capitalized; Re.str ".suite" ])
              in
              if not (Re.execp run_pattern content) then
                let loc =
                  Location.v
                    ~file:(Fpath.to_string runner_file)
                    ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
                in
                issues :=
                  Issue.v ~loc
                    {
                      fuzz_module = fuzz_mod;
                      fuzz_runner_file = Fpath.to_string runner_file;
                    }
                  :: !issues)
            fuzz_modules
        with _ -> ())
  in
  (* Check test stanzas *)
  List.iter
    (fun (t : Dune.test_info) -> check_stanza t.name t.files)
    (Dune.tests dune_describe);
  (* Check executable stanzas *)
  List.iter
    (fun (name, files) -> check_stanza name files)
    (Dune.executables dune_describe);
  List.rev !issues

let pp ppf { fuzz_module; fuzz_runner_file } =
  Fmt.pf ppf "Fuzz module %s is not included in %s" fuzz_module fuzz_runner_file

let rule =
  Rule.v ~code:"E715" ~title:"Fuzz Module Not Included" ~category:Testing
    ~hint:
      "All fuzz modules should be included in the fuzz runner (fuzz.ml) via \
       Fuzz_*.suite references. This ensures all fuzz tests are actually \
       executed."
    ~examples:[] ~pp (Project check)
