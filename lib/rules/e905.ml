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
          let all_files = try_readdir lib_dir in
          (* Only flag packages that actually use Wire *)
          let has_wire =
            List.exists
              (fun f ->
                Filename.check_suffix f ".ml"
                && (not (Filename.check_suffix f ".mli"))
                &&
                  try
                    let c =
                      In_channel.with_open_text
                        (Filename.concat lib_dir f)
                        In_channel.input_all
                    in
                    Astring.String.is_infix ~affix:"Wire." c
                  with Sys_error _ -> false)
              all_files
          in
          if has_wire then
            let mli_files =
              List.filter (fun f -> Filename.check_suffix f ".mli") all_files
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
                        let file = Filename.concat pkg f in
                        let loc = Location.in_file file in
                        issues := Issue.v ~loc { file; symbol = sym } :: !issues)
                    wire_symbols
                with Sys_error _ -> ())
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
