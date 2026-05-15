(** E944: Optional sub-library used, no gating depopt declared.

    Some opam packages expose conditionally-installed sub-libraries — for
    example, [bytesrw.zlib] only exists when [conf-zlib] was present at
    [bytesrw]'s build time. The conditionality is encoded in META ([exists_if])
    and the actual gate is one of the parent's opam [depopts:], but META doesn't
    tell us {b which} depopt gates which sub-library. We carry that knowledge in
    {!gating_table} — a small, explicit OCaml value that's easy to extend as new
    cases are found.

    The rule only fires for entries in the table: when a consumer uses
    [parent.sublib] and the table demands a [depopt], that depopt must be in the
    consumer's [depends:]. *)

type payload = { package : string; sublib : string; required_depopt : string }

(* Known (parent_pkg, sublib) -> required opam depopt. The table is the
   single source of truth — extend it when you find a new conditional
   sub-library worth gating. Each entry is sanity-checked against the
   parent's opam [depopts:] at build-index time (see [self_check]); if the
   parent doesn't actually list the depopt, the entry is stale and the
   rule logs a warning before any consumer findings. *)
let gating_table : (string * string * string) list =
  [
    (* bytesrw — conditional codec / hash sub-libraries each map 1:1 to a
       [conf-*] depopt. *)
    ("bytesrw", "zlib", "conf-zlib");
    ("bytesrw", "zstd", "conf-zstd");
    ("bytesrw", "blake3", "conf-libblake3");
    ("bytesrw", "md", "conf-libmd");
    ("bytesrw", "crypto", "conf-mbedtls");
    ("bytesrw", "tls", "conf-mbedtls");
    ("bytesrw", "xxhash", "conf-xxhash");
    (* fmt — tty needs [base-unix] for terminal width probing; cli needs
       [cmdliner]. *)
    ("fmt", "tty", "base-unix");
    ("fmt", "cli", "cmdliner");
    (* logs — adapter sub-libraries per output / concurrency backend. *)
    ("logs", "fmt", "fmt");
    ("logs", "top", "fmt");
    ("logs", "cli", "cmdliner");
    ("logs", "lwt", "lwt");
    ("logs", "threaded", "base-threads");
    ("logs", "browser", "js_of_ocaml-compiler");
  ]

(* Pre-bucket the table by parent for O(1) [parent] lookup, then sub-list
   search by [sublib]. The list is short enough that linear search per
   parent is fine. *)
let by_parent : (string, (string * string) list) Hashtbl.t =
  let tbl = Hashtbl.create 16 in
  List.iter
    (fun (parent, sub, depopt) ->
      let prev = try Hashtbl.find tbl parent with Not_found -> [] in
      Hashtbl.replace tbl parent ((sub, depopt) :: prev))
    gating_table;
  tbl

let lookup_gate parent sub =
  match Hashtbl.find_opt by_parent parent with
  | None -> None
  | Some entries -> List.assoc_opt sub entries

let split_lib lib =
  match String.index_opt lib '.' with
  | None -> None
  | Some i ->
      let parent = String.sub lib 0 i in
      let sub = String.sub lib (i + 1) (String.length lib - i - 1) in
      Some (parent, sub)

(* Once per index build, confirm every table entry's depopt is actually
   declared as a [depopts:] of its parent. A stale entry produces a
   diagnostic [E944] payload pointing at the table itself so the
   maintainer can update or drop it. *)
let self_check_warnings index =
  List.filter_map
    (fun (parent, sub, depopt) ->
      let parent_depopts = Project_index.depopts index parent in
      if parent_depopts = [] then
        None
        (* Parent not installed in this switch: can't verify; skip silently. *)
      else if List.mem depopt parent_depopts then None
      else
        Some
          {
            package = "merlint/lib/rules/e944.ml (gating_table)";
            sublib = parent ^ "." ^ sub;
            required_depopt =
              Fmt.str
                "STALE: %s is not in %s's depopts (%a). Update gating_table."
                depopt parent
                Fmt.(list ~sep:(any ", ") string)
                parent_depopts;
          })
    gating_table

let check_lib_use ~package ~depends_set used_lib =
  match split_lib used_lib with
  | None -> None
  | Some (parent, sub) -> (
      match lookup_gate parent sub with
      | None -> None
      | Some depopt ->
          if Dep_deps.String_set.mem depopt depends_set then None
          else Some { package; sublib = used_lib; required_depopt = depopt })

let check_package index package =
  let depends_set =
    Project_index.depends index package |> Dep_deps.String_set.of_list
  in
  let build_set =
    Project_index.build_depends index package |> Dep_deps.String_set.of_list
  in
  let depends_set = Dep_deps.String_set.union depends_set build_set in
  Project_index.runtime_library_uses index package
  |> List.filter_map (check_lib_use ~package ~depends_set)

let check (ctx : Context.project) =
  let index = Context.index ctx in
  let stale_loc = Location.in_file "merlint/lib/rules/e944.ml" in
  let stale =
    self_check_warnings index |> List.map (fun p -> Issue.v ~loc:stale_loc p)
  in
  let findings = Dep_deps.run_per_package ~check_package index in
  stale @ findings

let pp ppf p =
  Fmt.pf ppf
    "%s uses optional sub-library %s but %s is missing from %s.opam's \
     [depends:]. Add %S — it's the system-library wrapper that gates %s's \
     installation at build time."
    p.package p.sublib p.required_depopt p.package p.required_depopt p.sublib

let rule =
  Rule.v ~code:"E944" ~title:"Optional sub-library missing depopt declaration"
    ~category:Rule.Project_structure
    ~hint:
      "When you use [X.suffix] from package X, X's installation might have \
       skipped that sub-library because the system dep it gates wasn't \
       available at X's build time. The gating dep is one of X's opam \
       [depopts:]. Declare it in your own [depends:] so opam-install picks it \
       up in a fresh switch. The (parent, sub) → depopt mapping lives in \
       [merlint/lib/rules/e944.ml]'s [gating_table]; extend it when you find a \
       new case. Each entry is verified against X's actual depopts at run \
       time; stale entries surface as findings too."
    ~examples:[] ~pp (Project check)
