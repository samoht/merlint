(** E910: Package quality policy enforcement.

    Reads quality policy from [*.opam.template] files:
    {[
     x-quality: ["build" "test" "fuzz" "doc"]
    ]}

    Checks that declared quality features actually exist in the package.
    Reports:
    - Missing: declared in policy but not present (error)
    - Undeclared: present but not in policy (suggestion) *)

type finding = Missing of string | Undeclared of string
type payload = { package : string; findings : finding list }

let package_findings policy detected =
  let missing =
    policy
    |> List.filter (fun feature -> not (List.mem feature detected))
    |> List.map (fun feature -> Missing feature)
  in
  let undeclared =
    detected
    |> List.filter (fun feature -> not (List.mem feature policy))
    |> List.map (fun feature -> Undeclared feature)
  in
  missing @ undeclared

let check_package pkg =
  match
    (Project_index.Package.source_dir pkg, Project_index.Package.quality pkg)
  with
  | _, [] -> None
  | None, _ -> None
  | Some dir, policy -> (
      let name = Project_index.Package.name pkg in
      let detected = Project_index.Package.quality_features pkg in
      match package_findings policy detected with
      | [] -> None
      | findings ->
          let loc =
            Fpath.(dir / "dune-project")
            |> Loc.current_dir_relative |> Loc.in_file
          in
          Some (Issue.v ~loc { package = name; findings }))

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_packages_nodes
  |> List.filter_map check_package

let pp ppf { package; findings } =
  Fmt.pf ppf "%s: %s" package
    (String.concat "; "
       (List.map
          (function
            | Missing f -> Fmt.str "%s required by x-quality but missing" f
            | Undeclared f ->
                Fmt.str "%s present, consider adding to x-quality" f)
          findings))

let rule =
  Rule.v ~code:"E910" ~title:"Package quality policy"
    ~hint:
      "Add x-quality field to *.opam.template to declare required quality \
       features. Merlint checks that declared features actually exist."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
