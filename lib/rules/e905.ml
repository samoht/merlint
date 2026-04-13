(** E905: Wire struct_/module_ exposed in public API *)

type payload = { file : string; symbol : string }

let wire_symbols = [ "struct_"; "module_"; "c_stubs"; "ml_stubs" ]

(** Walk <pkg>/lib/*.mli looking for val struct_ / val module_ / val c_stubs /
    val ml_stubs. These belong in c/gen.ml. *)
let check (ctx : Context.project) =
  let root = ctx.project_root in
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let issues = ref [] in
  let packages = try_readdir root in
  List.iter
    (fun pkg ->
      let pkg_dir = Filename.concat root pkg in
      if
        Sys.file_exists pkg_dir && Sys.is_directory pkg_dir && pkg <> "_build"
        && pkg <> ".git" && pkg <> "_opam"
      then
        let lib_dir = Filename.concat pkg_dir "lib" in
        if Sys.file_exists lib_dir && Sys.is_directory lib_dir then
          let mli_files =
            try_readdir lib_dir
            |> List.filter (fun f -> Filename.check_suffix f ".mli")
          in
          List.iter
            (fun f ->
              try
                let path = Filename.concat lib_dir f in
                let content =
                  In_channel.with_open_text path In_channel.input_all
                in
                List.iter
                  (fun sym ->
                    let pattern = "val " ^ sym in
                    if Astring.String.is_infix ~affix:pattern content then
                      issues :=
                        Issue.v { file = Filename.concat pkg f; symbol = sym }
                        :: !issues)
                  wire_symbols
              with _ -> ())
            mli_files)
    packages;
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
