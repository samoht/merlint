(** E930: Sans-IO policy.

    Any package whose tags include any [codec.*] topic (the encoding kind) or
    the top-level [protocol] tag (a state machine wrapping a wire codec)
    declares the {e sans-io} contract. The rule enforces it by checking the
    package's [depends:] and every dune [(library ...)] in the package:

    - {b Pure sans-IO} (no [eio] tag): bans every IO runtime ([eio*], [lwt*],
      [miou*], [mirage*], [unix], [threads.posix]) and ambient-clock deps.
    - {b Eio adapter} ([codec.*]/[protocol] paired with [eio] tag): allows
      [eio*], still bans [lwt*], [miou*], [mirage*] -- the org standardises on
      Eio.

    A non-Eio IO runtime in either depends or a [(libraries ...)] field is a
    finding. *)

type kind = Non_codec | Pure_codec | Eio_codec

type finding =
  | Banned_in_depends of { dep : string }
  | Banned_in_libraries of { dune_file : string; lib : string }

type payload = { package : string; opam : string; findings : finding list }

let lwt_miou_mirage = [ "lwt"; "miou"; "mirage"; "mirage-clock"; "mirage-time" ]

let eio_family =
  [ "eio"; "eio_main"; "eio_posix"; "eio_linux"; "eio_windows"; "bytesrw.eio" ]

let unix_family = [ "unix"; "threads.posix"; "bytesrw.unix"; "ptime-clock.os" ]

let banned_for = function
  | Non_codec -> lwt_miou_mirage
  | Eio_codec -> lwt_miou_mirage
  | Pure_codec -> lwt_miou_mirage @ eio_family @ unix_family

let lib_matches ~banned name =
  let top =
    match String.index_opt name '.' with
    | Some i -> String.sub name 0 i
    | None -> name
  in
  List.exists (fun b -> b = name || b = top) banned

let kind_of_tags tags =
  if not (Opam_tags.has_sans_io tags) then Non_codec
  else if List.mem "eio" tags then Eio_codec
  else Pure_codec

module P = Project_index.Package
module L = Project_index.Library

let opam_path ~root pkg =
  match P.opam_path pkg with
  | Some path -> Fpath.to_string (Loc.relative_to ~root:(Fpath.v root) path)
  | None -> P.name pkg ^ ".opam"

let dune_file lib =
  match L.dune_file lib with
  | Some path -> Fpath.to_string (Loc.current_dir_relative path)
  | None -> L.name lib ^ "/dune"

(* Libraries declared under a [test/] or [tests/] subdirectory are private test
   utilities. They live at the IO edge and may pull in eio/unix freely. *)
let is_test_library ~package lib =
  match (P.source_dir package, L.source_dir lib) with
  | Some pkg_dir, Some lib_dir ->
      Loc.relative_to ~root:pkg_dir lib_dir
      |> Fpath.to_string |> String.split_on_char '/'
      |> List.exists (function "test" | "tests" -> true | _ -> false)
  | _ -> false

let check_package ~root pkg =
  let name = P.name pkg in
  let kind = kind_of_tags (P.tags pkg) in
  if kind = Non_codec then []
  else
    let banned = banned_for kind in
    let findings = ref [] in
    List.iter
      (fun dep ->
        if lib_matches ~banned dep then
          findings := Banned_in_depends { dep } :: !findings)
      (P.depends pkg);
    List.iter
      (fun lib ->
        let dune_file = dune_file lib in
        List.iter
          (fun dep ->
            if lib_matches ~banned dep then
              findings :=
                Banned_in_libraries { dune_file; lib = dep } :: !findings)
          (L.deps lib))
      (Project_index.package_libraries pkg
      |> List.filter (fun lib -> not (is_test_library ~package:pkg lib)));
    match List.rev !findings with
    | [] -> []
    | findings ->
        let opam = opam_path ~root pkg in
        let loc = Location.in_file opam in
        [ Issue.v ~loc { package = name; opam; findings } ]

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.concat_map (check_package ~root:ctx.project_root)

let pp_finding ppf = function
  | Banned_in_depends { dep } -> Fmt.pf ppf "depends: %s" dep
  | Banned_in_libraries { dune_file; lib } ->
      Fmt.pf ppf "%s libraries: %s" dune_file lib

let pp ppf { package; opam; findings } =
  let subject =
    if Filename.basename opam = opam then Filename.concat package opam else opam
  in
  Fmt.pf ppf "%s: sans-io policy violated by %a" subject
    Fmt.(list ~sep:(any "; ") pp_finding)
    findings

let rule =
  Rule.v ~code:"E930" ~title:"Sans-IO policy"
    ~hint:
      "Any package tagged codec.* or protocol must follow the sans-IO \
       contract. The org standardises on Eio: no package may depend on lwt, \
       miou, or mirage runtimes. Pure sans-IO packages (codec.* / protocol \
       without an eio tag) must additionally not depend on eio*, unix, or \
       ambient clocks."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
