(** E700: Fuzz Module Convention *)

type payload = { filename : string; module_name : string }

let is_fuzz_dir = File.is_in_fuzz_dir

let has_fuzz_runner content =
  (* Multi-module pattern: fuzz.ml calls Fuzz_*.run() *)
  Re.execp (Re.compile (Re.str ".run ()")) content
  || Re.execp (Re.compile (Re.str ".run()")) content

let uses_fuzz_module_runs content =
  Re.execp
    (Re.compile
       (Re.seq
          [
            Re.bow;
            Re.str "Fuzz_";
            Re.rep1 (Re.alt [ Re.alnum; Re.char '_' ]);
            Re.str ".run";
          ]))
    content

let defines_own_tests content =
  Re.execp (Re.compile (Re.str "add_test")) content

(** Check if fuzz.ml properly delegates to fuzz modules via Fuzz_*.run() instead
    of defining its own tests inline. *)
let check ctx =
  let files = Context.all_files ctx in
  List.concat_map
    (fun filename ->
      let fp = Fpath.v filename in
      if
        Fpath.has_ext ".ml" fp && is_fuzz_dir fp
        && Fpath.(fp |> rem_ext |> basename) = "fuzz"
      then
        try
          let content =
            In_channel.with_open_text filename In_channel.input_all
          in
          if defines_own_tests content && not (uses_fuzz_module_runs content)
          then
            [
              Issue.v
                ~loc:
                  (Location.v ~file:filename ~start_line:1 ~start_col:0
                     ~end_line:1 ~end_col:0)
                { filename; module_name = "fuzz" };
            ]
          else []
        with _ -> []
      else [])
    files

let pp ppf { filename; module_name = _ } =
  Fmt.pf ppf
    "Fuzz runner '%s' defines tests inline - use Fuzz_*.run() to delegate to \
     fuzz modules"
    (Filename.basename filename)

let rule =
  Rule.v ~code:"E700" ~title:"Fuzz Module Convention" ~category:Testing
    ~hint:
      "The fuzz runner (fuzz.ml) should call Fuzz_*.run() for each fuzz module \
       rather than defining tests with add_test directly. This keeps fuzz \
       tests organized per-module."
    ~examples:[] ~pp (Project check)
