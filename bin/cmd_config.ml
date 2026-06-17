open Cmdliner

let cmd =
  let doc = "Show the merlint.toml configuration file format" in
  let man =
    [
      `S Manpage.s_description;
      `P
        "Reference for the $(b,merlint.toml) configuration file format. The \
         file is parsed as TOML 1.1 and supports top-level settings keys plus \
         $(b,[[rules]]) blocks that exclude rules per file pattern.";
    ]
    @ Merlint_doc.Config_doc.man
  in
  let info = Cmd.info "config" ~doc ~man in
  Cmd.v info Term.(const (fun () -> ()) $ Observe.setup "merlint")
