(** E700: Fuzz Module Convention *)

type payload = { filename : string; module_name : string }

let uses_fuzz_module_suites content =
  Re.execp
    (Re.compile
       (Re.seq
          [
            Re.bow;
            Re.str "Fuzz_";
            Re.rep1 (Re.alt [ Re.alnum; Re.char '_' ]);
            Re.str ".suite";
          ]))
    content

let defines_own_tests content =
  Re.execp (Re.compile (Re.str "test_case")) content

(** Check if fuzz.ml properly delegates to fuzz modules via Fuzz_*.suite instead
    of defining its own tests inline. *)
let check ctx =
  let files = Context.all_files ctx in
  List.concat_map
    (fun filename ->
      let fp = Fpath.v filename in
      if
        Fpath.has_ext ".ml" fp && File.is_in_fuzz_dir fp
        && Fpath.(fp |> rem_ext |> basename) = "fuzz"
      then
        try
          let content =
            In_channel.with_open_text filename In_channel.input_all
          in
          if defines_own_tests content && not (uses_fuzz_module_suites content)
          then
            [
              Issue.v
                ~loc:
                  (Location.v ~file:filename ~start_line:1 ~start_col:0
                     ~end_line:1 ~end_col:0)
                { filename; module_name = "fuzz" };
            ]
          else []
        with Sys_error _ -> []
      else [])
    files

let pp ppf { filename; module_name = _ } =
  Fmt.pf ppf
    "Fuzz runner '%s' defines tests inline - use Fuzz_*.suite to delegate to \
     fuzz modules"
    (Filename.basename filename)

let rule =
  Rule.v ~code:"E700" ~title:"Fuzz Module Convention" ~category:Testing
    ~hint:
      "The fuzz runner (fuzz.ml) should collect Fuzz_*.suite from each fuzz \
       module rather than defining test_case directly. This keeps fuzz tests \
       organized per-module."
    ~examples:[] ~pp (Project check)
