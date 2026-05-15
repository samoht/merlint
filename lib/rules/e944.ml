(** E944: Optional sub-library used, no gating depopt declared.

    Some opam packages expose conditionally-installed sub-libraries — for
    example, [bytesrw.zlib] only exists when [conf-zlib] was installed at
    [bytesrw]'s build time. The conditionality is encoded in the parent
    package's META ([exists_if] on the subpackage) and the gating system
    dependency lives in the parent's opam [depopts:].

    If a consumer uses such a sub-library but declares none of the parent's
    [depopts:] in its own [depends:], [opam install] from a fresh switch may
    silently leave the sub-library out (the parent installs without the optional
    dep, the consumer's build then fails to find the sub-library). This rule
    warns on that gap.

    Hard-coded mappings handle the cases where we know exactly which depopt
    gates which sub-library — the warning suggests just that depopt instead of
    dumping the full list. Extended opportunistically. *)

type payload = {
  package : string;
  sublib : string;
  parent : string;
  suggested : string list;
}

(* Precise (sub-library, gating opam-pkg) overrides. The parent package's
   depopts can contain unrelated entries (cmdliner, b0, ...) that don't gate
   the sub-library in question. When we know the exact mapping, surface it;
   otherwise we fall back to listing every depopt as a candidate. *)
let precise_gate = function
  | "bytesrw", "zlib" -> Some [ "conf-zlib" ]
  | "bytesrw", "zstd" -> Some [ "conf-zstd" ]
  | "bytesrw", "blake3" -> Some [ "conf-libblake3" ]
  | "bytesrw", "md" -> Some [ "conf-libmd" ]
  | "bytesrw", "mbedtls" | "bytesrw", "tls" | "bytesrw", "crypto" ->
      Some [ "conf-mbedtls" ]
  | "bytesrw", "xxhash" -> Some [ "conf-xxhash" ]
  | _ -> None

let split_lib lib =
  match String.index_opt lib '.' with
  | None -> None
  | Some i ->
      let parent = String.sub lib 0 i in
      let sub = String.sub lib (i + 1) (String.length lib - i - 1) in
      Some (parent, sub)

let any_depopt_declared depopts depends_set =
  List.exists (fun d -> Dep_deps.String_set.mem d depends_set) depopts

let suggested_gates ~parent ~sub depopts =
  match precise_gate (parent, sub) with Some xs -> xs | None -> depopts

let check_split_lib ~index ~package ~depends_set ~parent ~sub used_lib =
  let optional = Project_index.optional_sublibs index parent in
  if not (List.mem sub optional) then None
  else
    let depopts = Project_index.depopts index parent in
    if depopts = [] || any_depopt_declared depopts depends_set then None
    else
      let suggested = suggested_gates ~parent ~sub depopts in
      Some { package; sublib = used_lib; parent; suggested }

let check_lib_use ~index ~package ~depends_set used_lib =
  match split_lib used_lib with
  | None -> None
  | Some (parent, sub) ->
      check_split_lib ~index ~package ~depends_set ~parent ~sub used_lib

let check_package index package =
  let depends_set =
    Project_index.depends index package |> Dep_deps.String_set.of_list
  in
  let build_set =
    Project_index.build_depends index package |> Dep_deps.String_set.of_list
  in
  let depends_set = Dep_deps.String_set.union depends_set build_set in
  Project_index.runtime_library_uses index package
  |> List.filter_map (check_lib_use ~index ~package ~depends_set)

let opam_loc index pkg =
  match Project_index.source_dir index pkg with
  | Some dir ->
      Location.in_file (Fpath.to_string (Fpath.add_seg dir (pkg ^ ".opam")))
  | None -> Location.in_file (pkg ^ ".opam")

let check (ctx : Context.project) =
  let index = Context.index ctx in
  List.concat_map
    (fun pkg ->
      let loc = opam_loc index pkg in
      check_package index pkg |> List.map (fun p -> Issue.v ~loc p))
    (Dep_deps.local_packages index)

let pp ppf p =
  match p.suggested with
  | [ one ] ->
      Fmt.pf ppf
        "%s uses optional sub-library %s (META declares it conditional). Add \
         %S to %s.opam's [depends:] so opam-install pulls in the system \
         library that gates it."
        p.package p.sublib one p.package
  | many ->
      Fmt.pf ppf
        "%s uses optional sub-library %s (META declares it conditional). %s \
         declares %d optional deps; none are in %s.opam's [depends:]. Add the \
         one that gates %s: %a."
        p.package p.sublib p.parent (List.length many) p.package p.sublib
        Fmt.(list ~sep:(any ", ") string)
        many

let rule =
  Rule.v ~code:"E944" ~title:"Optional sub-library missing depopt declaration"
    ~category:Rule.Project_structure
    ~hint:
      "When a library in your package's [(libraries L)] is of the form \
       [X.suffix] and X's META declares the [suffix] subpackage with \
       [exists_if], that sub-library only ships when one of X's [depopts:] was \
       installed at X's build time. Your package must declare that depopt in \
       its own [depends:] — otherwise [opam install] in a fresh switch may \
       install X without the optional dep, and the sub-library you use \
       silently won't be there. A small built-in table maps the common cases \
       (e.g. [bytesrw.zlib] → [conf-zlib]) to a single suggestion; for new \
       sub-libraries the warning lists all depopts so you can pick the right \
       one and we can extend the table."
    ~examples:[] ~pp (Project check)
