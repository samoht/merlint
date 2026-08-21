(** E905: Wire struct_/module_ exposed in public API *)

type payload = { file : string; symbol : string }

let wire_symbols = [ "struct_"; "module_"; "c_stubs"; "ml_stubs" ]

let file_uses_wire ctx path =
  try
    File_view.references_suffix
      (Context.file_view ctx path)
      [ "Wire"; "Codec"; "v" ]
  with File_view.Analysis_error _ -> false

let library_uses_wire ctx lib =
  Project_index.Library.files lib
  |> List.exists (fun fp ->
      let file = Context.resolve ctx fp in
      let f = Fpath.to_string fp in
      Filename.check_suffix f ".ml"
      && (not (Filename.check_suffix f ".mli"))
      && file_uses_wire ctx file)

let exposed_symbol_issues ctx pkg_name mli_path =
  try
    let names =
      Context.file_view ctx mli_path
      |> File_view.typed_items
      |> List.filter_map (fun item ->
          match File_view.Item.kind item with
          | Value -> Some (File_view.Item.name item)
          | _ -> None)
    in
    if names = [] then []
    else
      List.filter_map
        (fun sym ->
          if List.mem sym names then
            let file =
              Filename.concat pkg_name
                (Filename.basename (Context.string_of_path mli_path))
            in
            Some (Issue.v ~loc:(Location.in_file file) { file; symbol = sym })
          else None)
        wire_symbols
  with File_view.Analysis_error _ -> []

let check_package ctx pkg =
  let libs = Project_index.package_libraries pkg in
  let pkg_name = Project_index.Package.name pkg in
  if pkg_name = "wire" then []
  else
    let issues =
      libs
      |> List.concat_map Project_index.Library.files
      |> List.filter_map (fun fp ->
          let file = Context.resolve ctx fp in
          let s = Fpath.to_string fp in
          if Filename.check_suffix s ".mli" && ctx.Context.in_analyze_set file
          then Some file
          else None)
      |> List.concat_map (exposed_symbol_issues ctx pkg_name)
    in
    if issues = [] then []
    else if List.exists (library_uses_wire ctx) libs then issues
    else []

(** Walk <pkg>/lib/*.mli looking for val struct_ / val module_ / val c_stubs /
    val ml_stubs. These belong in c/gen.ml. *)
let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.concat_map (check_package ctx)

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
