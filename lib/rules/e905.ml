(** E905: Wire struct_/module_ exposed in public API *)

type payload = { file : string; symbol : string }

let wire_symbols = [ "struct_"; "module_"; "c_stubs"; "ml_stubs" ]
let try_readdir d = try Sys.readdir d |> Array.to_list with Sys_error _ -> []
let is_dir d = Sys.file_exists d && Sys.is_directory d
let skip_pkg = function "_build" | ".git" | "_opam" -> true | _ -> false

let file_contains path affix =
  try
    let content = In_channel.with_open_text path In_channel.input_all in
    Astring.String.is_infix ~affix content
  with Sys_error _ -> false

let package_uses_wire lib_dir all_files =
  List.exists
    (fun f ->
      Filename.check_suffix f ".ml"
      && (not (Filename.check_suffix f ".mli"))
      && file_contains (Filename.concat lib_dir f) "Wire.")
    all_files

let exposed_symbol_issues pkg lib_dir mli =
  let path = Filename.concat lib_dir mli in
  let content =
    try Some (In_channel.with_open_text path In_channel.input_all)
    with Sys_error _ -> None
  in
  match content with
  | None -> []
  | Some content ->
      List.filter_map
        (fun sym ->
          let pattern = "val " ^ sym in
          if Astring.String.is_infix ~affix:pattern content then
            let file = Filename.concat pkg mli in
            Some (Issue.v ~loc:(Location.in_file file) { file; symbol = sym })
          else None)
        wire_symbols

let check_package pkg =
  let pkg_dir = pkg in
  let lib_dir = Filename.concat pkg_dir "lib" in
  if
    (not (is_dir pkg_dir))
    || skip_pkg (Filename.basename pkg)
    || not (is_dir lib_dir)
  then []
  else
    let all_files = try_readdir lib_dir in
    if not (package_uses_wire lib_dir all_files) then []
    else
      all_files
      |> List.filter (fun f -> Filename.check_suffix f ".mli")
      |> List.concat_map (exposed_symbol_issues (Filename.basename pkg) lib_dir)

(** Walk <pkg>/lib/*.mli looking for val struct_ / val module_ / val c_stubs /
    val ml_stubs. These belong in c/gen.ml. *)
let check (ctx : Context.project) =
  let root = ctx.project_root in
  root |> try_readdir
  |> List.map (Filename.concat root)
  |> List.concat_map check_package

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
