(** E900: Wire.Codec without c/ directory *)

type payload = { package : string }

let try_readdir d = try Sys.readdir d |> Array.to_list with Sys_error _ -> []
let is_dir p = Sys.file_exists p && Sys.is_directory p
let skip_pkg = function "_build" | ".git" | "_opam" -> true | _ -> false

let file_uses_wire path =
  try
    let content = In_channel.with_open_text path In_channel.input_all in
    Astring.String.is_infix ~affix:"Wire.Codec.v " content
    || Astring.String.is_infix ~affix:"Codec.v \"" content
  with Sys_error _ -> false

let package_uses_wire lib_dir =
  try_readdir lib_dir
  |> List.filter (fun f ->
      Filename.check_suffix f ".ml" && not (Filename.check_suffix f ".mli"))
  |> List.exists (fun f -> file_uses_wire (Filename.concat lib_dir f))

let check_package root pkg =
  let pkg_dir = Filename.concat root pkg in
  let lib_dir = Filename.concat pkg_dir "lib" in
  let c_dir = Filename.concat pkg_dir "c" in
  if skip_pkg pkg || not (is_dir pkg_dir && is_dir lib_dir) then []
  else if (not (package_uses_wire lib_dir)) || is_dir c_dir then []
  else
    let loc = Location.in_file (Filename.concat pkg "dune-project") in
    [ Issue.v ~loc { package = pkg } ]

let check (ctx : Context.project) =
  let root = ctx.project_root in
  List.concat_map (check_package root) (try_readdir root)

let pp ppf { package } =
  Fmt.pf ppf
    "%s uses Wire.Codec but has no c/ directory for EverParse 3D generation"
    package

let rule =
  Rule.v ~code:"E900" ~title:"Wire.Codec without c/ directory"
    ~category:Code_generation
    ~hint:
      "Add a c/ directory with gen.ml that calls Wire_3d.main to generate .3d \
       files and C validators from the Wire codec definitions. See \
       ocaml-clcw/c/ for the pattern."
    ~examples:[] ~pp (Project check)
