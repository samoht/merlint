(** E900: Wire.Codec without c/ directory *)

type payload = { package : string }

(** Walk <pkg>/lib/*.ml looking for Wire.Codec or Wire.Field usage. If found and
    <pkg>/c/ doesn't exist, flag it. *)
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
          let ml_files =
            try_readdir lib_dir
            |> List.filter (fun f ->
                Filename.check_suffix f ".ml"
                && not (Filename.check_suffix f ".mli"))
          in
          let has_wire =
            List.exists
              (fun f ->
                try
                  let content =
                    In_channel.with_open_text
                      (Filename.concat lib_dir f)
                      In_channel.input_all
                  in
                  (* Only flag packages that define codecs, not ones
                     that just consume them *)
                  Astring.String.is_infix ~affix:"Wire.Codec.v " content
                  || Astring.String.is_infix ~affix:"Codec.v \"" content
                with _ -> false)
              ml_files
          in
          if has_wire then
            let c_dir = Filename.concat pkg_dir "c" in
            if not (Sys.file_exists c_dir && Sys.is_directory c_dir) then
              issues := Issue.v { package = pkg } :: !issues)
    packages;
  !issues

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
