(** E931: Ambient clock in sans-IO library code.

    Companion to {!E930}. E930 bans clock-source opam dependencies in sans-IO
    packages; E931 bans the {b call sites} themselves ([Mtime_clock.now],
    [Ptime_clock.now], [Unix.gettimeofday], [Unix.time], [Sys.time]) inside
    library code that the package's tags advertise as sans-IO.

    A package is sans-IO iff its opam [tags:] include any [codec.*] topic or the
    top-level [protocol] tag. Eligibility is read from [Project_index.tags].
    Library-to-package attribution and per-library source directories come from
    [Project_index.library_source_dir] — sibling adapter packages (e.g.
    [nox-tls-eio] alongside [nox-tls]) are therefore scanned against their own
    tags, not their sans-IO sister's. *)

module Issue_location = Location

type finding = {
  file : string;
  line : int;
  col : int;
  ident : string;
  suggestion : string;
}

type payload = { package : string; findings : finding list }

let banned_idents =
  [
    [ "Mtime_clock"; "now" ];
    [ "Mtime_clock"; "now_ns" ];
    [ "Mtime_clock"; "elapsed" ];
    [ "Mtime_clock"; "elapsed_ns" ];
    [ "Mtime_clock"; "now_d_ps" ];
    [ "Mtime_clock"; "period" ];
    [ "Ptime_clock"; "now" ];
    [ "Ptime_clock"; "now_d_ps" ];
    [ "Ptime_clock"; "current_tz_offset_s" ];
    [ "Ptime_clock"; "period" ];
    [ "Unix"; "gettimeofday" ];
    [ "Unix"; "time" ];
    [ "Sys"; "time" ];
  ]

let suggestion_for = function
  | [ "Mtime_clock"; _ ] ->
      "take [~now:Mtime.t] as a parameter and pass [Mtime_clock.now ()] from \
       the caller's adapter"
  | [ "Ptime_clock"; _ ] ->
      "take [~now:Ptime.t] as a parameter and pass [Ptime_clock.now ()] from \
       the caller's adapter"
  | [ "Unix"; "gettimeofday" ] | [ "Unix"; "time" ] | [ "Sys"; "time" ] ->
      "take [~now] as a parameter; the caller's adapter is the right place to \
       read the wall clock"
  | _ -> "thread the time value through your state-machine state instead"

let scan_file ctx ~filename =
  let view = Context.file_view ctx filename in
  let display_filename =
    Fpath.v filename |> Loc.current_dir_relative |> Fpath.to_string
  in
  let findings = ref [] in
  File_view.iter_applications view (fun call ->
      let callee = File_view.Call.callee call in
      let path =
        File_view.Name.prefix callee @ [ File_view.Name.base callee ]
      in
      List.iter
        (fun banned ->
          if List.length path >= List.length banned then
            let suffix =
              let rec drop n xs =
                if n <= 0 then xs
                else match xs with [] -> [] | _ :: xs -> drop (n - 1) xs
              in
              drop (List.length path - List.length banned) path
            in
            if suffix = banned then
              let loc = File_view.Call.loc call in
              findings :=
                {
                  file = display_filename;
                  line = loc.start.line;
                  col = loc.start.col;
                  ident = String.concat "." banned;
                  suggestion = suggestion_for banned;
                }
                :: !findings)
        banned_idents);
  List.rev !findings

(* Source [.ml] files for a library, exactly as dune sees them: the
   [(modules ...)] spec from the [dune] stanza, expanded against the
   library's source directory by [Project_index.Library.files]. *)
let library_ml_files lib =
  Project_index.Library.files lib
  |> List.filter (fun p -> Fpath.has_ext ".ml" p)
  |> List.map Fpath.to_string

let check (ctx : Context.project) =
  let module P = Project_index.Package in
  let index = Context.index ctx in
  List.concat_map
    (fun pkg ->
      if not (Opam_tags.has_sans_io (P.tags pkg)) then []
      else
        let mls =
          Project_index.package_libraries pkg
          |> List.concat_map library_ml_files
        in
        let findings =
          List.concat_map (fun filename -> scan_file ctx ~filename) mls
        in
        match findings with
        | [] -> []
        | _ ->
            let opam_path =
              match P.opam_path pkg with
              | Some path -> Fpath.to_string (Loc.current_dir_relative path)
              | None -> P.name pkg ^ ".opam"
            in
            let loc = Issue_location.in_file opam_path in
            [ Issue.v ~loc { package = P.name pkg; findings } ])
    (Project_index.packages_nodes index)

let pp_finding ppf { file; line; col; ident; suggestion } =
  Fmt.pf ppf "%s:%d:%d ambient clock [%s] in lib code: %s" file line col ident
    suggestion

let pp ppf { package; findings } =
  Fmt.pf ppf "%s: ambient clock in sans-IO lib code: %a" package
    Fmt.(list ~sep:(any "; ") pp_finding)
    findings

let rule =
  Rule.v ~code:"E931" ~title:"Ambient clock in sans-IO library code"
    ~category:Rule.Project_structure
    ~hint:
      "Sans-IO packages (tagged [codec.*] or [protocol]) must not read the \
       wall clock or monotonic clock from library code. Time is an input, not \
       a side effect: take [~now] as a parameter, let the caller's adapter or \
       CLI [bin/] call [Mtime_clock.now] / [Ptime_clock.now] / \
       [Unix.gettimeofday] / [Sys.time] and pass the value in. Library \
       attribution follows dune's [(public_name P.X)] via [Project_index] so a \
       sibling adapter package is scanned against its own tags, not its \
       sans-IO sister's."
    ~examples:[] ~pp (Project check)
