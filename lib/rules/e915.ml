(** E915: Opam tag metadata enforcement.

    Every [*.opam] file must declare a [tags:] field that contains the
    [org:blacksun] marker plus one or more topics from the canonical vocabulary.

    The vocabulary is loaded from [categories.toml] at the project root (each
    table header is a slug, e.g. [codec], [codec.text]). If that file is absent,
    falls back to the [topics:] list in [.merlint].

    Every finding is an error:
    - No [tags:] field in the opam file.
    - [tags:] present but [org:blacksun] missing.
    - A tag that is not [org:*] and not in the vocabulary. *)

type finding = Missing_tags | Missing_org | Unknown_topic of string
type payload = { package : string; opam : string; findings : finding list }

let dir_exists path = try Sys.is_directory path with Sys_error _ -> false

(** Extract the list of tags from an opam file. Handles both list
    ([tags: ["a" "b"]]) and single-string ([tags: "a"]) forms.

    Returns [None] if no [tags:] field is found or the file cannot be parsed. *)
let read_tags path =
  let string_of_value = function Opam.Value.String s -> Some s | _ -> None in
  try
    let ic = open_in path in
    Fun.protect
      ~finally:(fun () -> close_in ic)
      (fun () ->
        let r = Bytesrw.Bytes.Reader.of_in_channel ic in
        match Opam.field_reader ~file:path "tags" r with
        | None -> None
        | Some (Opam.Value.String s) -> Some [ s ]
        | Some (Opam.Value.List l) -> Some (List.filter_map string_of_value l)
        | Some _ -> Some [])
  with Sys_error _ -> None

let check_opam_file ~topics pkg_dir opam_name =
  let path = Filename.concat pkg_dir opam_name in
  let findings = ref [] in
  (match read_tags path with
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

let check (ctx : Context.project) =
  let root = ctx.project_root in
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
    | Missing_org -> "tags: missing org:blacksun marker"
    | Unknown_topic t -> Fmt.str "unknown topic %S" t
  in
  Fmt.pf ppf "%s/%s: %s" package opam
    (String.concat "; " (List.map describe findings))

let rule =
  Rule.v ~code:"E915" ~title:"Opam tag metadata"
    ~hint:
      "Every *.opam file must declare tags: [\"org:blacksun\" \"<topic>\" ...] \
       where each topic is a slug declared in categories.toml at the project \
       root (or listed in the topics: field of .merlint). Edit the package's \
       dune-project so dune regenerates the opam file."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
