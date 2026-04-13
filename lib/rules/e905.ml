(** E905: Wire struct_/module_ exposed in public API *)

type payload = { file : string; symbol : string }

let wire_symbols = [ "struct_"; "module_"; "c_stubs"; "ml_stubs" ]

let check (ctx : Context.project) =
  let desc = Context.dune_describe ctx in
  let libs = Dune.libraries desc in
  let issues = ref [] in
  List.iter
    (fun (lib : Dune.library_info) ->
      List.iter
        (fun f ->
          if Fpath.has_ext ".mli" f then
            try
              let content =
                In_channel.with_open_text (Fpath.to_string f)
                  In_channel.input_all
              in
              List.iter
                (fun sym ->
                  let pattern = "val " ^ sym in
                  if Astring.String.is_infix ~affix:pattern content then
                    issues :=
                      Issue.v { file = Fpath.to_string f; symbol = sym }
                      :: !issues)
                wire_symbols
            with _ -> ())
        lib.files)
    libs;
  !issues

let pp ppf { file; symbol } =
  Fmt.pf ppf "%s exposes Wire EverParse symbol `%s` in public API" file symbol

let rule =
  Rule.v ~code:"E905" ~title:"Wire struct_/module_ in public API"
    ~category:Code_generation
    ~hint:
      "Move struct_, module_, c_stubs, ml_stubs out of the .mli. These belong \
       in c/gen.ml where they are used to generate EverParse 3D files and C \
       stubs. The codec is the public API; the 3D projection is a build \
       artifact."
    ~examples:[] ~pp (Project check)
