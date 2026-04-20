(** E523: Avoid explicit [(modules ...)] stanzas in dune files.

    Dune picks up every [.ml] / [.mli] in a directory automatically; listing
    them by hand with [(modules foo bar baz)] is redundant and drifts as files
    are added or renamed. The rare legitimate use (splitting a dir into two
    libraries, or excluding a single scratch module) should be replaced with a
    separate directory whose dune has no [(modules ...)].

    {b How to fix:} drop the [(modules ...)] field. If two stanzas in one dune
    share a directory, split them into sibling directories. *)

type payload = { dune : string; stanza : string }

let find_dune_files root =
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let is_dir p = try Sys.is_directory p with Sys_error _ -> false in
  let rec walk dir acc =
    List.fold_left
      (fun acc name ->
        if
          name = "_build" || name = "_opam" || name = ".git"
          || String.starts_with ~prefix:"." name
        then acc
        else
          let p = Filename.concat dir name in
          if is_dir p then walk p acc
          else if name = "dune" then p :: acc
          else acc)
      acc (try_readdir dir)
  in
  walk root []

let read_file path =
  try
    let ic = open_in path in
    let n = in_channel_length ic in
    let s = really_input_string ic n in
    close_in ic;
    Some s
  with Sys_error _ -> None

(* Detect a [(modules ...)] field inside a stanza. Simple textual scan for
   "(modules" followed by whitespace — good enough for dune files, which are
   s-expressions with straightforward syntax. *)
let modules_re =
  Re.compile (Re.seq [ Re.str "(modules"; Re.alt [ Re.space; Re.char '\n' ] ])

let has_modules_field contents = Re.execp modules_re contents

let excerpt_re =
  Re.compile
    (Re.seq
       [
         Re.str "(modules";
         Re.alt [ Re.space; Re.char '\n' ];
         Re.rep (Re.compl [ Re.char ')' ]);
         Re.char ')';
       ])

let stanza_excerpt contents =
  match Re.exec_opt excerpt_re contents with
  | Some g -> Re.Group.get g 0
  | None -> "(modules ...)"

let check (ctx : Context.project) =
  let dunes = find_dune_files ctx.project_root in
  List.filter_map
    (fun path ->
      match read_file path with
      | None -> None
      | Some contents when has_modules_field contents ->
          Some (Issue.v { dune = path; stanza = stanza_excerpt contents })
      | Some _ -> None)
    dunes

let pp ppf { dune; stanza = _ } =
  Fmt.pf ppf
    "%s lists modules explicitly; drop the (modules ...) field and let dune \
     pick up every .ml in the directory"
    dune

let rule =
  Rule.v ~code:"E523" ~title:"Explicit (modules ...) stanza in dune"
    ~category:Rule.Project_structure
    ~hint:
      "Dune auto-discovers every .ml/.mli in a stanza's directory. If two \
       stanzas share a directory so you had to list modules explicitly, split \
       them into sibling directories instead. The rare exception is a stanza \
       that genuinely needs to exclude a scratch module — keep that aside and \
       let the rest auto-discover."
    ~examples:[] ~pp (Project check)
