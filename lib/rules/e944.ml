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

type payload = {
  package : string;
  sublib : string;
  required_depopt : string;
  table_loc : string;
}

(* Known (parent_pkg, sublib) -> required opam depopt. The fourth column is
   the [__LOC__] of the entry: it expands to the source position of the
   tuple at compile time, so error messages can point the maintainer at the
   right line when an entry goes stale or needs amending.

   Each entry is sanity-checked against the parent's opam [depopts:] at
   run time (see [self_check_warnings]); if the parent doesn't actually
   list the depopt, the entry is stale and the rule reports it with this
   location. *)
let gating_table : (string * string * string * string) list =
  [
    (* bytesrw — conditional codec / hash sub-libraries map 1:1 to a
       [conf-*] depopt. *)
    ("bytesrw", "zlib", "conf-zlib", __LOC__);
    ("bytesrw", "zstd", "conf-zstd", __LOC__);
    ("bytesrw", "blake3", "conf-libblake3", __LOC__);
    ("bytesrw", "md", "conf-libmd", __LOC__);
    ("bytesrw", "crypto", "conf-mbedtls", __LOC__);
    ("bytesrw", "tls", "conf-mbedtls", __LOC__);
    ("bytesrw", "xxhash", "conf-xxhash", __LOC__);
    (* fmt — tty needs [base-unix] for terminal width probing; cli needs
       [cmdliner]. *)
    ("fmt", "tty", "base-unix", __LOC__);
    ("fmt", "cli", "cmdliner", __LOC__);
    (* logs — adapter sub-libraries per output / concurrency backend. *)
    ("logs", "fmt", "fmt", __LOC__);
    ("logs", "top", "fmt", __LOC__);
    ("logs", "cli", "cmdliner", __LOC__);
    ("logs", "lwt", "lwt", __LOC__);
    ("logs", "threaded", "base-threads", __LOC__);
    ("logs", "browser", "js_of_ocaml-compiler", __LOC__);
    (* lwt — unix bindings live in a separate sub-library gated on
       [base-unix]. Other lwt depopts ([conf-libev], [base-threads]) gate
       runtime backends that are selected through [Lwt_engine]; they
       don't show up as [(libraries ...)] entries. *)
    ("lwt", "unix", "base-unix", __LOC__);
  ]

(* Pre-bucket the table by parent for O(1) [parent] lookup, then sub-list
   search by [sublib]. The list is short enough that linear search per
   parent is fine. *)
let by_parent : (string, (string * string * string) list) Hashtbl.t =
  let tbl = Hashtbl.create 16 in
  List.iter
    (fun (parent, sub, depopt, loc) ->
      let prev = try Hashtbl.find tbl parent with Not_found -> [] in
      Hashtbl.replace tbl parent ((sub, depopt, loc) :: prev))
    gating_table;
  tbl

let lookup_gate parent sub =
  match Hashtbl.find_opt by_parent parent with
  | None -> None
  | Some entries ->
      List.find_map
        (fun (s, depopt, loc) -> if s = sub then Some (depopt, loc) else None)
        entries

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
    (fun (parent, sub, depopt, loc) ->
      let parent_depopts = Project_index.depopts index parent in
      if parent_depopts = [] then
        None
        (* Parent not installed in this switch: can't verify; skip silently. *)
      else if List.mem depopt parent_depopts then None
      else
        Some
          {
            package = loc;
            sublib = parent ^ "." ^ sub;
            required_depopt =
              Fmt.str "%s not in %s's depopts (%a)" depopt parent
                Fmt.(list ~sep:(any ", ") string)
                parent_depopts;
            table_loc = loc;
          })
    gating_table

let check_lib_use ~package ~depends_set used_lib =
  match split_lib used_lib with
  | None -> None
  | Some (parent, sub) -> (
      match lookup_gate parent sub with
      | None -> None
      | Some (depopt, table_loc) ->
          if Dep_deps.String_set.mem depopt depends_set then None
          else
            Some
              {
                package;
                sublib = used_lib;
                required_depopt = depopt;
                table_loc;
              })

let check_package package =
  let module P = Project_index.Package in
  let depends_set = P.depends package |> Dep_deps.String_set.of_list in
  let build_set = P.build_depends package |> Dep_deps.String_set.of_list in
  let depends_set = Dep_deps.String_set.union depends_set build_set in
  P.runtime_library_uses package
  |> List.filter_map (check_lib_use ~package:(P.name package) ~depends_set)

(* For stale-table findings, attribute the issue to the .ml file holding
   [gating_table]. The exact line/column is in [table_loc] inside the
   payload and surfaces through {!pp}. *)
let table_file =
  match String.index_opt __LOC__ ':' with
  | Some i -> String.sub __LOC__ 0 i
  | None -> "merlint/lib/rules/e944.ml"

let check (ctx : Context.project) =
  let index = Context.index ctx in
  let stale_loc = Location.in_file table_file in
  let stale =
    self_check_warnings index |> List.map (fun p -> Issue.v ~loc:stale_loc p)
  in
  let findings = Dep_deps.run_per_package ~check_package index in
  stale @ findings

let pp ppf p =
  if p.package = p.table_loc then
    (* Stale-table finding: the [package] field doubles as the source
       location of the gating entry. *)
    Fmt.pf ppf "stale gating_table entry — %s. Update or drop the line."
      p.required_depopt
  else
    Fmt.pf ppf
      "%s uses optional sub-library %s but %s is missing from %s.opam's \
       [depends:]. Add %S — that's the depopt %s declares to gate %s's \
       installation (see %s)."
      p.package p.sublib p.required_depopt p.package p.required_depopt
      (match split_lib p.sublib with
      | Some (parent, _) -> parent
      | None -> p.sublib)
      p.sublib p.table_loc

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
