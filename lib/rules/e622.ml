(** E622: Package-less test stanza in multi-package project. *)

type payload = { dune_file : string; packages : string list }

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.unattributed_stanza_groups
  |> List.filter_map (fun (group : Project_index.unattributed_stanza_group) ->
      if
        not
          (List.exists
             (fun (stanza : Project_index.unattributed_stanza) ->
               stanza.kind = Project_index.Test)
             group.stanzas)
      then None
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
             }))

let pp ppf { dune_file; packages } =
  Fmt.pf ppf
    "%s is in a multi-package project (%s) and has a package-less test stanza. \
     Add [(package PKG)] so project-index can attribute the test scope without \
     guessing."
    dune_file
    (String.concat ", " packages)

let rule =
  Rule.v ~code:"E622" ~title:"Package-less test stanza" ~category:Rule.Testing
    ~hint:
      "In a multi-package dune project, test stanzas must say which package \
       owns them with [(package PKG)]. Without that field, project-index \
       cannot safely attribute test modules or test dependency scopes. Add \
       [(package <package-name>)] rather than relying on default-package \
       inference."
    ~examples:[] ~pp (Project check)
