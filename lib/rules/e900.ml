(** E900: Wire.Codec without c/ directory *)

type payload = { package : string }

let check (ctx : Context.project) =
  let desc = Context.dune_describe ctx in
  let libs = Dune.libraries desc in
  let issues = ref [] in
  List.iter
    (fun (lib : Dune.library_info) ->
      let has_wire =
        List.exists
          (fun f ->
            Fpath.has_ext ".ml" f
            &&
              try
                let content =
                  In_channel.with_open_text (Fpath.to_string f)
                    In_channel.input_all
                in
                Astring.String.is_infix ~affix:"Wire.Codec" content
                || Astring.String.is_infix ~affix:"Wire.Field" content
              with _ -> false)
          lib.files
      in
      if has_wire then
        let lib_dir =
          match lib.files with f :: _ -> Fpath.parent f | [] -> Fpath.v "."
        in
        let pkg_dir =
          if Fpath.basename lib_dir = "lib" then Fpath.parent lib_dir
          else lib_dir
        in
        let c_dir = Fpath.(pkg_dir / "c") in
        if
          not
            (Sys.file_exists (Fpath.to_string c_dir)
            && Sys.is_directory (Fpath.to_string c_dir))
        then issues := Issue.v { package = Fpath.to_string pkg_dir } :: !issues)
    libs;
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
