(** E932: Protocol package probe dependency.

    Protocol packages expose their event vocabulary through [probe]. The opam
    [protocol] tag is the package-level contract; this rule makes the contract
    mechanically visible by requiring [probe] in [depends:] and in the public
    protocol library's [(libraries ...)] stanza. *)

type payload =
  | Package_dep of { package : string }
  | Library_dep of { package : string; library : string }

module P = Project_index.Package

let has_protocol_tag tags = List.exists (String.equal "protocol") tags
let has_probe_dep pkg = List.exists (String.equal "probe") (P.depends pkg)

let library_has_probe lib =
  List.exists (String.equal "probe") (Project_index.Library.deps lib)

let public_libraries pkg =
  Project_index.package_libraries pkg
  |> List.filter (fun lib ->
      Project_index.Library.public_name lib |> Option.is_some)

let check_package pkg =
  if not (has_protocol_tag (P.tags pkg)) then []
  else
    let package = P.name pkg in
    if not (has_probe_dep pkg) then [ Package_dep { package } ]
    else
      public_libraries pkg
      |> List.filter (fun lib -> not (library_has_probe lib))
      |> List.map (fun lib ->
          Library_dep { package; library = Project_index.Library.name lib })

let check ctx = Context.index ctx |> Dep_deps.run_per_package ~check_package

let pp ppf = function
  | Package_dep { package } ->
      Fmt.pf ppf "%s is tagged [protocol] but does not depend on probe" package
  | Library_dep { package; library } ->
      Fmt.pf ppf
        "%s is tagged [protocol], but public library %s does not link probe in \
         its (libraries ...) stanza"
        package library

let rule =
  Rule.v ~code:"E932" ~title:"Protocol probe dependency"
    ~hint:
      "Every package tagged [protocol] must depend on [probe], and each public \
       protocol library in that package must link [probe] in its [(libraries \
       ...)] stanza. Protocol libraries should declare a closed [Event.t] \
       vocabulary and expose [Event.emit_probe] so adapters can publish typed \
       Runtime_events probes without owning an in-process subscription API."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
