(** E940: Dune warnings flag missing.

    The top-level [dune] file of every OCaml project (or each subtree in a
    monorepo) should enable the canonical warning set via
    [(env (dev (flags :standard %{dune-warnings})))]. Without it, the project
    builds with a different warning set than its dune-project peers, and
    warnings that would fail CI elsewhere quietly pass locally. *)

let log_src = Logs.Src.create "merlint.rules.e940" ~doc:"E940 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

type kind = Missing_file | Missing_flags
type payload = { dune_path : string; kind : kind }

(* Top-level (env ...) stanza references %{dune-warnings} -- the substring
   is enough; we don't pin a specific shape so per-project variations
   (extra fields, alternate profiles) still satisfy the rule. *)
let rec mentions_dune_warnings (sexp : Sexp.t) =
  match sexp with
  | Sexp.Atom s -> Astring.String.is_infix ~affix:"dune-warnings" s
  | Sexp.List xs -> List.exists mentions_dune_warnings xs

let parse_dune_sexps path =
  try
    let ic = open_in path in
    Fun.protect
      ~finally:(fun () -> close_in ic)
      (fun () ->
        let content = really_input_string ic (in_channel_length ic) in
        match Sexp.Value.parse_string_many content with
        | Ok stanzas -> Some stanzas
        | Error _ -> Some [])
  with Sys_error _ -> None

let is_env_stanza = function
  | Sexp.List (Sexp.Atom "env" :: _) -> true
  | _ -> false

let dune_warning_status dune_path =
  match parse_dune_sexps dune_path with
  | None -> Some Missing_file
  | Some sexps ->
      let env_stanzas = List.filter is_env_stanza sexps in
      if List.exists mentions_dune_warnings env_stanzas then None
      else Some Missing_flags

let is_dir path = try Sys.is_directory path with Sys_error _ -> false

let is_skipped name =
  name = "_build" || name = "_opam" || name = ".git" || name = "node_modules"
  || (String.length name > 0 && name.[0] = '.')

(* Every directory that ships its own [dune-project] is treated as a build
   root: the actual project root for single-project repos, every subtree
   for monopam-managed monorepos. *)
let build_roots project_root =
  let roots = ref [] in
  if Sys.file_exists (Filename.concat project_root "dune-project") then
    roots := project_root :: !roots;
  (try
     Sys.readdir project_root |> Array.to_list
     |> List.iter (fun name ->
         if is_skipped name then ()
         else
           let path = Filename.concat project_root name in
           if
             is_dir path
             && Sys.file_exists (Filename.concat path "dune-project")
           then roots := path :: !roots)
   with Sys_error _ -> ());
  List.rev !roots

let check (ctx : Context.project) =
  let roots = build_roots ctx.project_root in
  Log.debug (fun m -> m "E940: %d build root(s)" (List.length roots));
  List.filter_map
    (fun root ->
      let dune_path = Filename.concat root "dune" in
      Option.map
        (fun kind ->
          let loc = Location.in_file dune_path in
          Issue.v ~loc { dune_path; kind })
        (dune_warning_status dune_path))
    roots

let pp ppf { dune_path; kind } =
  match kind with
  | Missing_file ->
      Fmt.pf ppf
        "%s missing -- create it with [(env (dev (flags :standard \
         %%{dune-warnings})))] so this project uses the canonical warning set"
        dune_path
  | Missing_flags ->
      Fmt.pf ppf
        "%s does not enable %%{dune-warnings}; add [(env (dev (flags :standard \
         %%{dune-warnings})))] so standalone opam builds fail on warnings"
        dune_path

let rule =
  Rule.v ~code:"E940" ~title:"Dune warnings flag"
    ~category:Rule.Project_structure
    ~hint:
      "Every project (or subtree) should enable [%{dune-warnings}] on the dev \
       profile so warnings are uniform across builds. Add the stanza [(env \
       (dev (flags :standard %{dune-warnings})))] to the top-level [dune] \
       file. Note [%{dune-warnings}] requires [(lang dune 3.21)] or newer in \
       the corresponding [dune-project]."
    ~examples:[] ~pp (Project check)
