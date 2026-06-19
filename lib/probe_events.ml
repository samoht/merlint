(** Runtime probes emitted by merlint. *)

module F = Probe.Fields

type analysis_payload = { project_root : string; files : int; rules : int }

let analysis_span =
  Probe.span "merlint.analysis" ~doc:"Merlint analysis run"
    F.(
      obj (fun project_root files rules -> { project_root; files; rules })
      |> field "project_root" string ~enc:(fun t -> t.project_root)
      |> field "files" int ~enc:(fun t -> t.files)
      |> field "rules" int ~enc:(fun t -> t.rules)
      |> seal)

let analysis ~project_root ~files ~rules f =
  Probe.with_span analysis_span { project_root; files; rules } f

type project_rules_payload = { rules : int; jobs : int }

let project_rules_span =
  Probe.span "merlint.project_rules" ~doc:"Merlint project-rule batch"
    F.(
      obj (fun rules jobs -> { rules; jobs })
      |> field "rules" int ~enc:(fun t -> t.rules)
      |> field "jobs" int ~enc:(fun t -> t.jobs)
      |> seal)

let project_rules ~rules ~jobs f =
  Probe.with_span project_rules_span { rules; jobs } f

type rule_payload = { rule : string }

let project_rule_span =
  Probe.span "merlint.project_rule" ~doc:"Merlint project-rule execution"
    F.(
      obj (fun rule -> { rule })
      |> field "rule" string ~enc:(fun t -> t.rule)
      |> seal)

let project_rule ~rule f = Probe.with_span project_rule_span { rule } f

type file_payload = { file : string; file_rules : int; pass_rules : int }

let file_analysis_span =
  Probe.span "merlint.file_analysis" ~doc:"Merlint per-file analysis"
    F.(
      obj (fun file file_rules pass_rules -> { file; file_rules; pass_rules })
      |> field "file" string ~enc:(fun t -> t.file)
      |> field "file_rules" int ~enc:(fun t -> t.file_rules)
      |> field "pass_rules" int ~enc:(fun t -> t.pass_rules)
      |> seal)

let file_analysis ~file ~file_rules ~pass_rules f =
  Probe.with_span file_analysis_span { file; file_rules; pass_rules } f

type file_rule_payload = { rule : string; file : string }

let file_rule_span =
  Probe.span "merlint.file_rule" ~doc:"Merlint direct file-rule execution"
    F.(
      obj (fun rule file -> { rule; file })
      |> field "rule" string ~enc:(fun t -> t.rule)
      |> field "file" string ~enc:(fun t -> t.file)
      |> seal)

let file_rule ~rule ~file f = Probe.with_span file_rule_span { rule; file } f
