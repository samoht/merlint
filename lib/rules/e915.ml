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

let dir_exists path = try Sys.is_directory path with Sys_error _ -> false

let check_opam_file ~topics pkg_dir opam_name =
  let path = Filename.concat pkg_dir opam_name in
  let findings = ref [] in
  (match Opam_tags.read_opt path with
  | None -> findings := [ Missing_tags ]
  | Some tags ->
      let has_org =
        List.exists
          (fun t -> String.length t >= 4 && String.sub t 0 4 = "org:")
          tags
      in
      if not has_org then findings := Missing_org :: !findings;
      if topics <> [] then
        List.iter
          (fun tag ->
            let is_org =
              String.length tag >= 4 && String.sub tag 0 4 = "org:"
            in
            if (not is_org) && not (List.mem tag topics) then
              findings := Unknown_topic tag :: !findings)
          tags);
  List.rev !findings

let list_opam_files pkg_dir =
  try
    Sys.readdir pkg_dir |> Array.to_list
    |> List.filter (fun f -> Filename.check_suffix f ".opam")
  with Sys_error _ -> []

(* Two signals enable this rule:

   - [sources.toml] at the project root: the monopam marker that maps
     subtree directories to upstream URLs. Single-package projects don't
     have one.
   - [categories.toml] at the project root: the rule's own vocabulary
     file. Its presence means the project is opting into the
     tagged-opam convention even outside a monopam monorepo.

   Either one is enough; absent both, the rule stays silent. *)
let opted_in root =
  Sys.file_exists (Filename.concat root "sources.toml")
  || Sys.file_exists (Filename.concat root "categories.toml")

let check (ctx : Context.project) =
  let root = ctx.project_root in
  if not (opted_in root) then []
  else
    let topics =
      match Categories.load root with [] -> ctx.config.topics | slugs -> slugs
    in
    let issues = ref [] in
    let try_readdir d =
      try Sys.readdir d |> Array.to_list with Sys_error _ -> []
    in
    let skip = [ "_build"; ".git"; "_opam"; "node_modules" ] in
    let packages = try_readdir root in
    List.iter
      (fun pkg ->
        let pkg_dir = Filename.concat root pkg in
        if dir_exists pkg_dir && not (List.mem pkg skip) then
          List.iter
            (fun opam ->
              let findings = check_opam_file ~topics pkg_dir opam in
              if findings <> [] then
                let loc = Location.in_file (Filename.concat pkg opam) in
                issues :=
                  Issue.v ~loc { package = pkg; opam; findings } :: !issues)
            (list_opam_files pkg_dir))
      packages;
    !issues

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
