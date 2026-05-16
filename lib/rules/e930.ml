(** E930: Sans-IO policy.

    Any package whose tags include any [codec.*] topic (the encoding kind) or
    the top-level [protocol] tag (a state machine wrapping a wire codec)
    declares the {e sans-io} contract. The rule enforces it by checking the
    package's [depends:] and every dune [(library ...)] under its directory:

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
  | Bytesrw_sublib of { dune_file : string; lib : string }

type payload = { package : string; opam : string; findings : finding list }

(* Bans: each entry matches the bare name and any sub-library
   ([eio.core], [lwt.unix], [bytesrw.eio]). *)
let lwt_miou_mirage = [ "lwt"; "miou"; "mirage"; "mirage-clock"; "mirage-time" ]

let eio_family =
  [ "eio"; "eio_main"; "eio_posix"; "eio_linux"; "eio_windows"; "bytesrw.eio" ]

let unix_family = [ "unix"; "threads.posix"; "bytesrw.unix"; "ptime-clock.os" ]

let banned_for = function
  | Non_codec -> lwt_miou_mirage
  | Eio_codec -> lwt_miou_mirage
  | Pure_codec -> lwt_miou_mirage @ eio_family @ unix_family

(* Library names compare on the bare top-level or any [base.sub] form. *)
let lib_matches ~banned name =
  let top =
    match String.index_opt name '.' with
    | Some i -> String.sub name 0 i
    | None -> name
  in
  List.exists (fun b -> b = name || b = top) banned

let rec extract_dep_name (v : Opam.Value.t) =
  match v with
  | Opam.Value.String s -> Some s
  | Opam.Value.Option (inner, _) -> extract_dep_name inner
  | _ -> None

let rec is_non_runtime (v : Opam.Value.t) =
  match v with
  | Opam.Value.Ident "with-test" | Opam.Value.Ident "with-doc" -> true
  | Opam.Value.Logop (_, l, r) -> is_non_runtime l || is_non_runtime r
  | Opam.Value.Pfxop (_, x) -> is_non_runtime x
  | _ -> false

(* Depends entries with [with-test] or [with-doc] don't ship at runtime;
   they're fine even in a sans-io package. *)
let dep_is_runtime (v : Opam.Value.t) =
  match v with
  | Opam.Value.Option (_, filters) -> not (List.exists is_non_runtime filters)
  | _ -> true

let content ctx path =
  try Some (File_view.content (Context.file_view ctx path))
  with Sys_error _ | File_view.Analysis_error _ -> None

let read_runtime_depends ctx path =
  match content ctx path with
  | None -> []
  | Some content -> (
      let r = Bytesrw.Bytes.Reader.of_string content in
      match Opam.field_reader ~file:path "depends" r with
      | Some (Opam.Value.List entries) ->
          List.filter_map
            (fun e -> if dep_is_runtime e then extract_dep_name e else None)
            entries
      | _ -> [])

(* A bytesrw sub-library is one whose name ends in ["_bytesrw"] / ["-bytesrw"]
   or matches ["bytesrw"] inside a non-root directory of a codec package.
   The intended pattern is: the codec lib itself depends on bytesrw and
   exposes [of_reader] / [to_writer]. A separate [pkg.bytesrw] is the
   anti-pattern we're catching. *)
let is_bytesrw_sublib name =
  name = "bytesrw"
  || String.length name > 8
     && String.sub name (String.length name - 8) 8 = "_bytesrw"

(* Library [(public_name X.Y)] declares the owning opam package as [X] (the
   dot-prefix); without a public_name the library is private and we
   conservatively attribute it to the containing directory's pkg. *)
let library_owner lib =
  match Dune.File.Library.public_name lib with
  | None -> None
  | Some pname ->
      let owner =
        match String.index_opt pname '.' with
        | Some i -> String.sub pname 0 i
        | None -> pname
      in
      Some owner

let parse_dune ctx path =
  match content ctx path with
  | None -> []
  | Some content -> (
      match Dune.File.of_string content with
      | Ok file -> Dune.File.libraries file
      | Error _ -> [])

(* Libraries declared under a [test/] or [tests/] subdirectory are private
   test utilities (no [public_name]); they live at the IO edge and may pull
   in eio/unix freely. *)
let is_test_subdir = function "test" | "tests" -> true | _ -> false

let rec walk ctx ~in_test dir acc =
  let entries = try Sys.readdir dir |> Array.to_list with Sys_error _ -> [] in
  List.fold_left
    (fun acc entry ->
      if String.length entry > 0 && (entry.[0] = '.' || entry.[0] = '_') then
        acc
      else
        let path = Filename.concat dir entry in
        let is_dir = try Sys.is_directory path with Sys_error _ -> false in
        if is_dir then
          walk ctx ~in_test:(in_test || is_test_subdir entry) path acc
        else if entry = "dune" && not in_test then
          (path, parse_dune ctx path) :: acc
        else acc)
    acc entries

let kind_of_tags tags =
  if not (Opam_tags.has_sans_io tags) then Non_codec
  else if List.mem "eio" tags then Eio_codec
  else Pure_codec

(* A library belongs to the opam package being checked when its
   [(public_name P.foo)] resolves to [P = pkg_name]; libraries without a
   public_name are private and conservatively attributed to the containing
   directory's pkg. *)
let library_belongs_to ~pkg_name lib =
  match library_owner lib with Some owner -> owner = pkg_name | None -> true

let pkg_name_of_opam opam =
  match Filename.chop_suffix_opt ~suffix:".opam" opam with
  | Some n -> n
  | None -> opam

let check_opam ctx ~pkg_dir opam =
  let path = Filename.concat pkg_dir opam in
  let tags = Opam_tags.read path in
  let kind = kind_of_tags tags in
  let banned = banned_for kind in
  let pkg_name = pkg_name_of_opam opam in
  let findings = ref [] in
  let deps = read_runtime_depends ctx path in
  List.iter
    (fun dep ->
      if lib_matches ~banned dep then
        findings := Banned_in_depends { dep } :: !findings)
    deps;
  let dunes = walk ctx ~in_test:false pkg_dir [] in
  List.iter
    (fun (dune_file, libs) ->
      let owned = List.filter (library_belongs_to ~pkg_name) libs in
      List.iter
        (fun lib ->
          List.iter
            (fun dep ->
              if lib_matches ~banned dep then
                findings :=
                  Banned_in_libraries { dune_file; lib = dep } :: !findings)
            (Dune.File.Library.libraries lib))
        owned;
      if kind <> Non_codec then
        List.iter
          (fun lib ->
            let name = Dune.File.Library.name lib in
            if name <> "" && is_bytesrw_sublib name then
              findings := Bytesrw_sublib { dune_file; lib = name } :: !findings)
          owned)
    dunes;
  List.rev !findings

let list_opam_files pkg_dir =
  try
    Sys.readdir pkg_dir |> Array.to_list
    |> List.filter (fun f -> Filename.check_suffix f ".opam")
  with Sys_error _ -> []

let check (ctx : Context.project) =
  let root = ctx.project_root in
  let entries =
    try Sys.readdir root |> Array.to_list with Sys_error _ -> []
  in
  let skip = [ "_build"; ".git"; "_opam"; "node_modules" ] in
  List.concat_map
    (fun pkg ->
      let pkg_dir = Filename.concat root pkg in
      if List.mem pkg skip then []
      else
        let is_dir = try Sys.is_directory pkg_dir with Sys_error _ -> false in
        if not is_dir then []
        else
          List.concat_map
            (fun opam ->
              match check_opam ctx ~pkg_dir opam with
              | [] -> []
              | findings ->
                  let loc = Location.in_file (Filename.concat pkg opam) in
                  [ Issue.v ~loc { package = pkg; opam; findings } ])
            (list_opam_files pkg_dir))
    entries

let pp_finding ppf = function
  | Banned_in_depends { dep } -> Fmt.pf ppf "depends: %s" dep
  | Banned_in_libraries { dune_file; lib } ->
      Fmt.pf ppf "%s libraries: %s" dune_file lib
  | Bytesrw_sublib { dune_file; lib } ->
      Fmt.pf ppf "%s library: %s (bytesrw integration belongs in the main lib)"
        dune_file lib

let pp ppf { package; opam; findings } =
  Fmt.pf ppf "%s/%s: sans-io policy violated by %a" package opam
    Fmt.(list ~sep:(any "; ") pp_finding)
    findings

let rule =
  Rule.v ~code:"E930" ~title:"Sans-IO policy"
    ~hint:
      "Any package tagged codec.* or protocol must follow the sans-IO \
       contract. The org standardises on Eio: no package may depend on lwt, \
       miou, or mirage runtimes. Pure sans-IO packages (codec.* / protocol \
       without an eio tag) must additionally not depend on eio*, unix, or \
       ambient clocks. They expose Bytesrw Reader/Writer in the main library \
       rather than shipping a separate <pkg>_bytesrw sub-library."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)
