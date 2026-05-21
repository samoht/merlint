(** E727: Package-less fuzz runner in multi-package project. *)

type payload = {
  dune_file : string;
  packages : string list;
  aliases : string list;
}

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.unattributed_stanza_groups
  |> List.filter_map (fun (group : Project_index.unattributed_stanza_group) ->
      let aliases =
        group.stanzas
        |> List.filter_map (fun (stanza : Project_index.unattributed_stanza) ->
            match stanza.kind with
            | Project_index.Fuzz -> Some stanza.name
            | Project_index.Test | Project_index.Mdx -> None)
        |> List.sort_uniq String.compare
      in
      if aliases = [] then None
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
               aliases;
             }))

let pp_alias ppf alias = Fmt.pf ppf "@%s" alias

let pp ppf { dune_file; packages; aliases } =
  Fmt.pf ppf
    "%s is in a multi-package project (%s) and has package-less fuzz aliases \
     (%a). Add [(package PKG)] to the corresponding [(rule (alias ...))] \
     stanzas so project-index can attribute the fuzz test scope without \
     guessing."
    dune_file
    (String.concat ", " packages)
    Fmt.(list ~sep:(any ", ") pp_alias)
    aliases

let rule =
  Rule.v ~code:"E727" ~title:"Package-less fuzz runner" ~category:Rule.Testing
    ~hint:
      "In a multi-package dune project, the rules that attach a private fuzz \
       runner to the runtest and fuzz aliases must say which package owns them \
       with [(package PKG)]. The executable stays private; put the package \
       field on the [(rule (alias runtest) ...)] and [(rule (alias fuzz) ...)] \
       stanzas."
    ~examples:[] ~pp (Project check)
