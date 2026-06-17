open Cmdliner
open Merlint

let normalise_topic = function
  | None -> None
  | Some t ->
      let upper = String.uppercase_ascii t in
      if
        String.length upper > 0
        && upper.[0] = 'E'
        && String.for_all (fun c -> c = 'E' || (c >= '0' && c <= '9')) upper
      then Some (`Rule upper)
      else if String.lowercase_ascii t = "config" then Some `Config
      else Some (`Topic t)

let format_arg =
  let doc =
    "Output format: $(b,text) (default, terminal-friendly), $(b,md) \
     (Markdown), $(b,html) (HTML reference)."
  in
  let parse s =
    match Doc.format_of_string s with Ok f -> Ok f | Error e -> Error (`Msg e)
  in
  let print ppf = function
    | Doc.Text -> Fmt.string ppf "text"
    | Markdown -> Fmt.string ppf "md"
    | Html -> Fmt.string ppf "html"
  in
  let format_conv = Arg.conv (parse, print) in
  Arg.(value & opt format_conv Doc.Text & info [ "format" ] ~docv:"FORMAT" ~doc)

let all_arg =
  let doc = "Render documentation for every rule, not just one topic." in
  Arg.(value & flag & info [ "all" ] ~doc)

let output_arg =
  let doc =
    "Write to $(docv) instead of stdout. Required directories are not created."
  in
  Arg.(
    value & opt (some string) None & info [ "o"; "output" ] ~docv:"FILE" ~doc)

let topic_arg =
  let doc =
    "Topic to show help for. Omit for the main manual. Pass $(b,config) for \
     the configuration reference, or a rule code (e.g. $(b,E100))."
  in
  Arg.(value & pos 0 (some string) None & info [] ~docv:"TOPIC" ~doc)

let write_output output body =
  match output with
  | None ->
      print_string body;
      `Ok ()
  | Some path ->
      let oc = open_out path in
      Fun.protect
        ~finally:(fun () -> close_out oc)
        (fun () -> output_string oc body);
      `Ok ()

let rule_of_code code =
  List.find_opt (fun r -> Rule.code r = code) Data.all_rules

let run () topic format all output =
  match (normalise_topic topic, all) with
  | _, true -> write_output output (Doc.render_all ~format Data.all_rules)
  | None, false -> (
      (* Bare [merlint help]: emit a one-line-per-rule index. Grep-friendly:
         users can pipe through [grep magic] to find a rule. *)
      match format with
      | Doc.Text -> write_output output (Doc.render_index Data.all_rules)
      | _ -> write_output output (Doc.render_all ~format Data.all_rules))
  | Some `Config, false -> (
      match format with
      | Doc.Text -> `Help (`Auto, Some "config")
      | _ ->
          `Error
            ( true,
              "config doc generation is not supported yet; pass a rule code or \
               --all" ))
  | Some (`Topic t), false ->
      `Error
        (true, Fmt.str "unknown help topic %S (try a rule code or config)" t)
  | Some (`Rule code), false -> (
      match rule_of_code code with
      | None -> `Error (true, Fmt.str "unknown rule code %S" code)
      | Some rule -> write_output output (Doc.render_rule ~format rule))

let cmd =
  let doc = "Show help for a topic (e.g. $(b,merlint help E100))" in
  let man =
    [
      `S Manpage.s_description;
      `P
        "Render the manual for $(b,merlint), one of its subcommands, or a \
         single rule. The same renderer powers the generated HTML reference \
         and Markdown style guide via $(b,--format) and $(b,--all).";
      `S Manpage.s_examples;
      `P "Browse a rule on the terminal:";
      `Pre "  $(mname) help E100";
      `P "Regenerate the HTML reference for all rules:";
      `Pre "  $(mname) help --all --format=html -o docs/index.html";
      `P "Regenerate the Markdown style guide:";
      `Pre "  $(mname) help --all --format=md -o STYLE_GUIDE.md";
    ]
  in
  let info = Cmd.info "help" ~doc ~man in
  Cmd.v info
    Term.(
      ret
        (const run $ Observe.setup "merlint" $ topic_arg $ format_arg $ all_arg
       $ output_arg))
