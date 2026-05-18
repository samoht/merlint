(** E915: Opam tag metadata enforcement.

    Runs only when the project root carries one of two opt-in signals: a
    [sources.toml] (the monopam monorepo marker) or a [categories.toml] (the tag
    vocabulary file). Single-package and non-monorepo projects without either
    are skipped silently.

    When the rule does run, every [*.opam] must declare a [tags:] field
    containing one [org:<name>] marker plus one or more topics from the
    project's canonical vocabulary (from [categories.toml] or [topics = [...]]
    in [merlint.toml]).

    Findings:
    - No [tags:] field in the opam file.
    - [tags:] present but no [org:*] marker.
    - A tag that is not [org:*] and not in the vocabulary. *)

type finding = Missing_tags | Missing_org | Unknown_topic of string
type payload = { package : string; opam : string; findings : finding list }

let check_tags ~topics ~has_tags tags =
  let findings = ref [] in
  (if not has_tags then findings := [ Missing_tags ]
   else
     let has_org =
       List.exists
         (fun t -> String.length t >= 4 && String.sub t 0 4 = "org:")
         tags
     in
     if not has_org then findings := Missing_org :: !findings;
     if topics <> [] then
       List.iter
         (fun tag ->
           let is_org = String.length tag >= 4 && String.sub tag 0 4 = "org:" in
           if (not is_org) && not (List.mem tag topics) then
             findings := Unknown_topic tag :: !findings)
         tags);
  List.rev !findings

(* Two signals enable this rule:

   - [sources.toml] at the project root: the monopam marker that maps
     subtree directories to upstream URLs. Single-package projects don't
     have one.
   - [categories.toml] at the project root: the rule's own vocabulary
     file. Its presence means the project is opting into the
     tagged-opam convention even outside a monopam monorepo.

   Either one is enough; absent both, the rule stays silent. *)
let opted_in root =
  Fs.file_exists (Filename.concat root "sources.toml")
  || Fs.file_exists (Filename.concat root "categories.toml")

let loc_in_project ~root path =
  Loc.relative_to ~root:(Fpath.v root) path |> Loc.in_file

let issue_for_package ~root ~topics pkg =
  let name = Project_index.Package.name pkg in
  let opam = name ^ ".opam" in
  let tags = Project_index.Package.tags pkg in
  let has_tags = Project_index.Package.has_tags pkg in
  match check_tags ~topics ~has_tags tags with
  | [] -> None
  | findings ->
      let loc =
        match Project_index.Package.opam_path pkg with
        | Some path -> loc_in_project ~root path
        | None -> Location.in_file opam
      in
      Some (Issue.v ~loc { package = name; opam; findings })

let check (ctx : Context.project) =
  let root = ctx.project_root in
  if not (opted_in root) then []
  else
    let topics =
      match Categories.load root with [] -> ctx.config.topics | slugs -> slugs
    in
    Context.index ctx |> Project_index.source_packages_nodes
    |> List.filter_map (issue_for_package ~root ~topics)

let pp ppf { package; opam; findings } =
  let describe = function
    | Missing_tags -> "missing tags: field"
    | Missing_org -> "tags: missing org:* marker"
    | Unknown_topic t -> Fmt.str "unknown topic %S" t
  in
  Fmt.pf ppf "%s/%s: %s" package opam
    (String.concat "; " (List.map describe findings))

let rule =
  Rule.v ~code:"E915" ~title:"Opam tag metadata"
    ~hint:
      "Runs only when the project root has a sources.toml (monopam monorepo \
       marker) or a categories.toml (the tag vocabulary). When it does run, \
       every *.opam must declare tags: [\"org:<your-org>\" \"<topic>\" ...] \
       where each topic is a slug from categories.toml / merlint.toml's topics \
       list. Edit the package's dune-project so dune regenerates the opam \
       file."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
