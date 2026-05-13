(** E931: Ambient clock in sans-IO library code.

    Companion to {!E930}. E930 bans clock-source opam dependencies in sans-IO
    packages; E931 bans the {b call sites} themselves ([Mtime_clock.now],
    [Ptime_clock.now], [Unix.gettimeofday], [Unix.time], [Sys.time]) inside
    library code that the package's tags advertise as sans-IO.

    A package is sans-IO iff its opam [tags:] include any [codec.*] topic or the
    top-level [protocol] tag. Eligibility is read from
    [Monopam_info_index.tags]. Library-to-package attribution and per-library
    source directories come from [Monopam_info_index.library_source_dir] —
    sibling adapter packages (e.g. [nox-tls-eio] alongside [nox-tls]) are
    therefore scanned against their own tags, not their sans-IO sister's. *)

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

let is_sans_io_tag t =
  t = "codec"
  || (String.length t > 6 && String.sub t 0 6 = "codec.")
  || t = "protocol"

let parse_structure ~filename =
  match
    let ic = open_in filename in
    Fun.protect
      ~finally:(fun () -> close_in ic)
      (fun () -> really_input_string ic (in_channel_length ic))
  with
  | exception Sys_error _ -> None
  | content -> Ast.parse_structure ~filename content

let scan_file ~filename =
  match parse_structure ~filename with
  | None -> []
  | Some structure ->
      let findings = ref [] in
      Ast.iter_expressions structure (fun expr ->
          match expr.pexp_desc with
          | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _) ->
              let path = Longident.flatten txt in
              if List.exists (( = ) path) banned_idents then begin
                let pos = expr.pexp_loc.loc_start in
                findings :=
                  {
                    file = filename;
                    line = pos.pos_lnum;
                    col = pos.pos_cnum - pos.pos_bol;
                    ident = String.concat "." path;
                    suggestion = suggestion_for path;
                  }
                  :: !findings
              end
          | _ -> ());
      List.rev !findings

(* Source files of a library: every [.ml] in the library's dune directory.
   Acceptable over-approximation — [(modules ...)] filters would tighten it but
   add no false positives we care about (an extra .ml scanned is benign). *)
let library_ml_files index lib =
  match Monopam_info_index.library_source_dir index lib with
  | None -> []
  | Some dir -> (
      try
        Sys.readdir (Fpath.to_string dir)
        |> Array.to_list
        |> List.filter (fun f -> Filename.check_suffix f ".ml")
        |> List.map (fun f -> Fpath.to_string Fpath.(dir / f))
      with Sys_error _ -> [])

let check (ctx : Context.project) =
  let index = Context.index ctx in
  List.concat_map
    (fun pkg ->
      let tags = Monopam_info_index.tags index pkg in
      if not (List.exists is_sans_io_tag tags) then []
      else
        let mls =
          Monopam_info_index.libraries index pkg
          |> List.concat_map (fun lib -> library_ml_files index lib)
        in
        let findings =
          List.concat_map (fun filename -> scan_file ~filename) mls
        in
        match findings with
        | [] -> []
        | _ ->
            let opam_path =
              match Monopam_info_index.source_dir index pkg with
              | Some dir -> Fpath.to_string Fpath.(dir / (pkg ^ ".opam"))
              | None -> pkg ^ ".opam"
            in
            let loc = Location.in_file opam_path in
            [ Issue.v ~loc { package = pkg; findings } ])
    (Monopam_info_index.packages index)

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
       attribution follows dune's [(public_name P.X)] via [Monopam_info_index] \
       so a sibling adapter package is scanned against its own tags, not its \
       sans-IO sister's."
    ~examples:[] ~pp (Project check)
