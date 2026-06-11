(** E932: Protocol package probe dependency.

    Protocol packages expose their event vocabulary through [ocaml-probe]. The
    opam [protocol] tag is the package-level contract; this rule makes the
    contract mechanically visible by requiring [ocaml-probe] in [depends:]. *)

type payload = { package : string }

module P = Project_index.Package

let has_protocol_tag tags = List.exists (String.equal "protocol") tags
let has_probe_dep pkg = List.exists (String.equal "ocaml-probe") (P.depends pkg)

let check_package pkg =
  if has_protocol_tag (P.tags pkg) && not (has_probe_dep pkg) then
    [ { package = P.name pkg } ]
  else []

let check ctx = Context.index ctx |> Dep_deps.run_per_package ~check_package

let pp ppf { package } =
  Fmt.pf ppf "%s is tagged [protocol] but does not depend on ocaml-probe"
    package

let rule =
  Rule.v ~code:"E932" ~title:"Protocol probe dependency"
    ~hint:
      "Every package tagged [protocol] must depend on [ocaml-probe]. Protocol \
       libraries should declare a closed [Event.t] vocabulary and expose \
       [Event.emit_probe] so adapters can publish typed Runtime_events probes \
       without owning an in-process subscription API."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
