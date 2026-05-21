(** E922: Package-less MDX stanza in multi-package project. *)

type payload = {
  dune_file : string;
  packages : string list;
  files : string list;
}

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.unattributed_stanza_groups
  |> List.filter_map (fun (group : Project_index.unattributed_stanza_group) ->
      let files =
        group.stanzas
        |> List.filter_map (fun (stanza : Project_index.unattributed_stanza) ->
            match stanza.kind with
            | Project_index.Mdx -> Some stanza.name
            | Project_index.Test | Project_index.Fuzz -> None)
        |> List.sort_uniq String.compare
      in
      if files = [] then None
      else
        let dune_file = group.dune_file in
        let loc =
          Location.v
            ~file:(Fpath.to_string dune_file)
            ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
        in
        Some
          (Issue.v ~loc
             {
               dune_file = Fpath.to_string dune_file;
               packages = group.packages;
               files;
             }))

let pp_file ppf file = Fmt.pf ppf "%s" file

let pp ppf { dune_file; packages; files } =
  Fmt.pf ppf
    "%s is in a multi-package project (%s) and has package-less MDX stanzas \
     covering %a. Add [(package PKG)] to each [(mdx ...)] stanza so \
     project-index can attribute documentation checks without guessing."
    dune_file
    (String.concat ", " packages)
    Fmt.(list ~sep:(any ", ") pp_file)
    files

let rule =
  Rule.v ~code:"E922" ~title:"Package-less MDX stanza"
    ~category:Rule.Documentation
    ~hint:
      "In a multi-package dune project, MDX stanzas must say which package \
       owns the documentation check with [(package PKG)]. Dune attaches MDX to \
       runtest automatically; the package field is for ownership and \
       package-filtering, not alias plumbing."
    ~examples:[] ~pp (Project check)
