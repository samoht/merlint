(** Classify a cross-module type as abstract or transparent by reading its
    declaring module's [.cmti]. Pure: uses [Cmt_format.read_cmt] only, never
    [Env] / [Load_path] global state. *)

module Cmt = Ocaml_typing.Cmt_format
module T = Ocaml_typing.Typedtree
module Types = Ocaml_typing.Types
module Ident = Ocaml_typing.Ident

type t = Abstract | Transparent of Types.type_expr list | Unknown

(* The modules and module types the compilation unit under analysis defines
   itself. A module bound here is not a compilation unit and has no interface on
   disk - a functor applied here writes no artefact at all - so a type it names
   resolves only from the module type the typechecker recorded for the binding.
   Keyed by the binding's source name, which is how [Path.name] spells the head
   of such a type's path ("Streams.key", "Id.t"). *)
type locals = {
  modules : (string, Types.module_type) Hashtbl.t;
  module_types : (string, Types.module_type) Hashtbl.t;
  memo : (string option * string, t) Hashtbl.t;
}

let local_module locals name =
  match locals with None -> None | Some l -> Hashtbl.find_opt l.modules name

let local_module_type locals name =
  match locals with
  | None -> None
  | Some l -> Hashtbl.find_opt l.module_types name

let head path =
  match String.split_on_char '.' path with first :: _ -> first | [] -> path

let names_local locals path =
  match locals with
  | None -> false
  | Some l -> Hashtbl.mem l.modules (head path)

(* [.cmti] basename without extension (e.g. "x509__Key_type") -> path, scanned
   once per project root from both the project's install layout and the opam
   switch, so external (e.g. eio, bytesrw, cmarkit) types resolve too. *)
let indexes : (string, (string, string) Hashtbl.t) Hashtbl.t = Hashtbl.create 4

let rec scan tbl ~suffix dir =
  match Sys.readdir dir with
  | exception Sys_error _ -> ()
  | entries ->
      Array.iter
        (fun entry ->
          let path = Filename.concat dir entry in
          if try Sys.is_directory path with Sys_error _ -> false then
            scan tbl ~suffix path
          else if Filename.check_suffix entry suffix then
            (* first writer wins: prefer the project's own install over opam,
               and a .cmti interface over a .cmt implementation *)
            let key = Filename.remove_extension entry in
            if not (Hashtbl.mem tbl key) then Hashtbl.replace tbl key path)
        entries

let cmti_index root =
  match Hashtbl.find_opt indexes root with
  | Some tbl -> tbl
  | None ->
      let tbl = Hashtbl.create 4096 in
      let install =
        Filename.concat (Dune.Root.build_dir root) "install/default/lib"
      in
      let opam = Filename.concat root "_opam/lib" in
      (* .cmti interfaces take priority; .cmt implementations then fill in
         modules that ship no .mli (e.g. eio's Eio__Fs). *)
      scan tbl ~suffix:".cmti" install;
      scan tbl ~suffix:".cmti" opam;
      scan tbl ~suffix:".cmt" install;
      scan tbl ~suffix:".cmt" opam;
      Hashtbl.replace indexes root tbl;
      tbl

(* The member types a transparent declaration exposes: the aliased type for a
   manifest, the field types for a record, the argument types for a variant.
   A caller compares them in turn so a transparent type containing an abstract
   one is still rejected. *)
let decl_member_types (td : Types.type_declaration) =
  match td.Types.type_kind with
  (* Prefer the concrete representation over a manifest: a record/variant
     defined as [type t = M.t = { ... }] exposes its fields here as plain
     types, while the manifest [M.t] is a short sibling path we may not be
     able to resolve. *)
  | Types.Type_record (labels, _) ->
      List.map (fun (l : Types.label_declaration) -> l.ld_type) labels
  | Types.Type_variant (cstrs, _) ->
      List.concat_map
        (fun (cd : Types.constructor_declaration) ->
          match cd.cd_args with
          | Types.Cstr_tuple types -> types
          | Types.Cstr_record labels ->
              List.map (fun (l : Types.label_declaration) -> l.ld_type) labels)
        cstrs
  | Types.Type_abstract _ | Types.Type_open -> (
      match td.type_manifest with Some ty -> [ ty ] | None -> [])

(* A private type still exposes its representation (you may read it, only not
   build it), so its members are visible and comparing it structurally is as
   safe as the members allow - recurse rather than reject outright. *)
let classify_decl (td : Types.type_declaration) =
  match (td.Types.type_kind, td.type_manifest) with
  | Types.Type_abstract _, None -> Abstract
  | _ -> Transparent (decl_member_types td)

let memo : (string * string option * string, t) Hashtbl.t = Hashtbl.create 256

(* The library wrapper is lowercased, but a compiler-mangled component like
   "Eio__File" keeps its module suffix: lowercase only up to the first "__".
   "Eio__" is the namespace marker for library eio: strip the trailing "__" so
   it resolves to eio.cmti (its submodules live inside it). *)
let mangle_lib first =
  let n = String.length first in
  let first =
    if n >= 2 && String.equal (String.sub first (n - 2) 2) "__" then
      String.sub first 0 (n - 2)
    else first
  in
  match String.index_opt first '_' with
  | Some i
    when i + 1 < String.length first && Char.equal first.[i + 1] '_' && i > 0 ->
      String.lowercase_ascii (String.sub first 0 i)
      ^ String.sub first i (String.length first - i)
  | _ -> String.lowercase_ascii first

(* Joining a "Eio__" wrapper with the next module yields "eio____File"; a
   compilation-unit name never has three underscores in a row, so fold any
   such run back to two. *)
let collapse_underscores s =
  let buf = Buffer.create (String.length s) in
  let n = String.length s in
  let i = ref 0 in
  while !i < n do
    if Char.equal s.[!i] '_' then (
      let j = ref !i in
      while !j < n && Char.equal s.[!j] '_' do
        incr j
      done;
      let run = !j - !i in
      Buffer.add_string buf (if run >= 3 then "__" else String.make run '_');
      i := !j)
    else (
      Buffer.add_char buf s.[!i];
      incr i)
  done;
  Buffer.contents buf

let path_parts p = String.split_on_char '.' (Ocaml_typing.Path.name p)

(* Read the unit's own module and module-type bindings. Only the top level is
   recorded: a nested module is reached by navigating the enclosing binding's
   module type, which the resolver below already does for a submodule path. *)
let locals tree =
  let modules = Hashtbl.create 16 and module_types = Hashtbl.create 8 in
  let add tbl name mty =
    match name with Some n -> Hashtbl.replace tbl n mty | None -> ()
  in
  let add_modtype (mtd : T.module_type_declaration) =
    match mtd.mtd_type with
    | Some mty -> add module_types (Some mtd.mtd_name.txt) mty.T.mty_type
    | None -> ()
  in
  let structure_item (item : T.structure_item) =
    match item.str_desc with
    | T.Tstr_module mb -> add modules mb.mb_name.txt mb.mb_expr.mod_type
    | T.Tstr_recmodule mbs ->
        List.iter
          (fun (mb : T.module_binding) ->
            add modules mb.mb_name.txt mb.mb_expr.mod_type)
          mbs
    | T.Tstr_modtype mtd -> add_modtype mtd
    | _ -> ()
  in
  let signature_item (item : T.signature_item) =
    match item.sig_desc with
    | T.Tsig_module md -> add modules md.md_name.txt md.md_type.mty_type
    | T.Tsig_recmodule mds ->
        List.iter
          (fun (md : T.module_declaration) ->
            add modules md.md_name.txt md.md_type.mty_type)
          mds
    | T.Tsig_modtype mtd -> add_modtype mtd
    | _ -> ()
  in
  (match tree with
  | None -> ()
  | Some (`Implementation str) -> List.iter structure_item str.T.str_items
  | Some (`Interface sg) -> List.iter signature_item sg.T.sig_items);
  { modules; module_types; memo = Hashtbl.create 64 }

(* A wrapped library records a reference to a sibling compilation unit by its
   short alias - [Css.declaration] is [type declaration = Declaration.declaration],
   stored as ["Declaration.declaration"], not ["Cascade__Declaration.declaration"].
   Such a name resolves only once the enclosing library is known: [qualify
   "cascade" "Declaration.declaration"] re-expresses it as a sub-unit of the
   library, ["cascade__Declaration.declaration"]. *)
let qualify lib path =
  match String.split_on_char '.' path with
  | first :: rest -> String.concat "." ((lib ^ "__" ^ first) :: rest)
  | [] -> path

let library_of ?enclosing path =
  let head =
    match String.split_on_char '.' path with first :: _ -> first | [] -> path
  in
  let m = mangle_lib head in
  match String.index_opt m '_' with
  (* "cascade__Css" -> "cascade": a wrapped sub-unit names its library before
     the "__". *)
  | Some i when i + 1 < String.length m && Char.equal m.[i + 1] '_' && i > 0 ->
      String.sub m 0 i
  (* A bare head ("Declaration", "Re") is either a short sibling alias - whose
     library only the [enclosing] context knows - or a library of its own. *)
  | _ -> ( match enclosing with Some l -> l | None -> m)

(* Resolve a fully qualified type to its declaration kind by reading the
   declaring module's interface. [module_path] is the chain of modules from the
   library wrapper down to the type; [mods] are submodules still to navigate
   inside the located interface; [name] is the type.

   A library .cmti carries each top-level module, so the deepest module may live
   inside a shallower [.cmti] as a submodule: try the longest
   "lib__M1__...__Mk" that exists and navigate the remaining modules. A module
   alias ([module M = N]) is followed to the aliased module, bounded by [fuel]
   so a cyclic alias cannot loop forever. *)
let rec resolve_module ~fuel ~locals index module_path mods name =
  if fuel <= 0 then Unknown
  else
    match module_path with
    | [] -> Unknown
    | first :: rest -> (
        (* A module this unit binds itself: read the module type the
           typechecker recorded for it rather than looking for an interface
           that cannot exist. Falls through to the index when that walk stops
           short, so a local alias to a real compilation unit still resolves. *)
        match local_module locals first with
        | Some mty -> (
            match
              resolve_in_tmty ~fuel:(fuel - 1) ~locals index mty (rest @ mods)
                name
            with
            | Unknown ->
                resolve_in_index ~fuel ~locals index first rest mods name
            | k -> k)
        | None -> resolve_in_index ~fuel ~locals index first rest mods name)

and resolve_in_index ~fuel ~locals index first rest mods name =
  let lib = mangle_lib first in
  let nav = rest @ mods in
  let rec try_depth taken remaining =
    let mangled =
      collapse_underscores (String.concat "__" (lib :: List.rev taken))
    in
    let here =
      match Hashtbl.find_opt index mangled with
      | Some cmti -> read_cmti ~fuel ~locals index cmti remaining name
      | None -> Unknown
    in
    match (here, remaining) with
    | Unknown, m :: more -> try_depth (m :: taken) more
    | k, _ -> k
  in
  try_depth [] nav

and read_cmti ~fuel ~locals index cmti mods name =
  match Cmt.read_cmt cmti with
  | exception _ -> Unknown
  | cmt -> (
      match cmt.Cmt.cmt_annots with
      | Cmt.Interface sg -> resolve_in_sig ~fuel ~locals index sg mods name
      | Cmt.Implementation str ->
          resolve_in_str ~fuel ~locals index str mods name
      | _ -> Unknown)

(* Same as [resolve_in_sig], but over a [.cmt] implementation's structure, for
   modules that ship no [.mli] (their inferred interface is the structure). An
   [include M] brings M's items into this module ([Tstr_include]); search its
   expanded signature so a type re-exported that way still resolves. *)
and resolve_in_str ~fuel ~locals index (str : T.structure) mods name =
  let from_item (item : T.structure_item) =
    match (item.str_desc, mods) with
    | T.Tstr_type (_, decls), [] ->
        List.find_map
          (fun (d : T.type_declaration) ->
            if String.equal d.typ_name.txt name then
              Some (classify_decl d.typ_type)
            else None)
          decls
    | T.Tstr_module mb, m :: rest
      when match mb.mb_name.txt with
           | Some n -> String.equal n m
           | None -> false ->
        Some (resolve_in_mod ~fuel ~locals index mb.mb_expr rest name)
    | T.Tstr_include incl, _ -> (
        match resolve_in_tsig ~fuel ~locals index incl.incl_type mods name with
        | Unknown -> None
        | k -> Some k)
    | _ -> None
  in
  Option.value ~default:Unknown (List.find_map from_item str.str_items)

and resolve_in_mod ~fuel ~locals index (me : T.module_expr) mods name =
  match me.mod_desc with
  | T.Tmod_structure str -> resolve_in_str ~fuel ~locals index str mods name
  | T.Tmod_constraint (me, _, _, _) ->
      resolve_in_mod ~fuel ~locals index me mods name
  | T.Tmod_ident (p, _) ->
      resolve_module ~fuel:(fuel - 1) ~locals index (path_parts p) mods name
  | _ -> Unknown

(* Walk into nested submodules [mods] then read the named type's declaration. An
   [include module type of M] (the "_intf trick": the real declarations live in
   an [.ml]-only [M_intf], re-exported here) appears as a single [Tsig_include]
   whose [incl_type] holds the expanded signature; search it so a type or
   submodule surfaced that way still resolves instead of reading as abstract. *)
and resolve_in_sig ~fuel ~locals index (sg : T.signature) mods name =
  let from_item (item : T.signature_item) =
    match (item.sig_desc, mods) with
    | T.Tsig_type (_, decls), [] ->
        List.find_map
          (fun (d : T.type_declaration) ->
            if String.equal d.typ_name.txt name then
              Some (classify_decl d.typ_type)
            else None)
          decls
    | T.Tsig_module md, m :: rest
      when match md.md_name.txt with
           | Some n -> String.equal n m
           | None -> false ->
        Some (resolve_in_mty ~fuel ~locals index md.md_type rest name)
    | T.Tsig_include incl, _ -> (
        match resolve_in_tsig ~fuel ~locals index incl.incl_type mods name with
        | Unknown -> None
        | k -> Some k)
    | _ -> None
  in
  Option.value ~default:Unknown (List.find_map from_item sg.sig_items)

and resolve_in_mty ~fuel ~locals index (mty : T.module_type) mods name =
  match mty.mty_desc with
  | T.Tmty_signature sg -> resolve_in_sig ~fuel ~locals index sg mods name
  (* [module M = N]: M is the module at path N, so resolve N afresh and navigate
     the rest of the chain inside it. *)
  | T.Tmty_alias (p, _) ->
      resolve_module ~fuel:(fuel - 1) ~locals index (path_parts p) mods name
  | _ -> Unknown

(* The expanded signature carried by an include is a [Types.signature], not a
   Typedtree one, so it needs its own walk: navigate the remaining submodules
   then read the named type's declaration the same way. *)
and resolve_in_tsig ~fuel ~locals index (sg : Types.signature) mods name =
  match mods with
  | [] ->
      List.find_map
        (function
          | Types.Sig_type (id, td, _, _) when String.equal (Ident.name id) name
            ->
              Some (classify_decl td)
          | _ -> None)
        sg
      |> Option.value ~default:Unknown
  | m :: rest -> (
      match
        List.find_map
          (function
            | Types.Sig_module (id, _, md, _, _)
              when String.equal (Ident.name id) m ->
                Some md.Types.md_type
            | _ -> None)
          sg
      with
      | Some mty -> resolve_in_tmty ~fuel ~locals index mty rest name
      | None -> Unknown)

and resolve_in_tmty ~fuel ~locals index (mty : Types.module_type) mods name =
  match mty with
  | Types.Mty_signature sg -> resolve_in_tsig ~fuel ~locals index sg mods name
  | Types.Mty_alias p ->
      resolve_module ~fuel:(fuel - 1) ~locals index (path_parts p) mods name
  (* [module M : S = ...] records the named signature, so read what S declares.
     Only a module type declared in this unit is reachable this way; one named
     from another unit stays unresolved. *)
  | Types.Mty_ident p -> (
      match local_module_type locals (Ocaml_typing.Path.name p) with
      | Some mty -> resolve_in_tmty ~fuel:(fuel - 1) ~locals index mty mods name
      | None -> Unknown)
  | _ -> Unknown

let resolve ~root ~locals ~path =
  let index = cmti_index root in
  match List.rev (String.split_on_char '.' path) with
  | type_name :: (_ :: _ as module_rev) ->
      resolve_module ~fuel:10 ~locals index (List.rev module_rev) [] type_name
  | _ -> Unknown

let classify ~root ?locals ?lib ~path () =
  let compute () =
    match (resolve ~root ~locals ~path, lib) with
    (* a short sibling that did not resolve on its own: retry it as a sub-unit
       of the enclosing library *)
    | Unknown, Some l -> resolve ~root ~locals ~path:(qualify l path)
    | k, _ -> k
  in
  (* A path headed by one of this unit's own modules answers differently per
     unit, so it is memoised in that unit's own table, not the shared one. *)
  match locals with
  | Some l when names_local locals path -> (
      match Hashtbl.find_opt l.memo (lib, path) with
      | Some k -> k
      | None ->
          let k = compute () in
          Hashtbl.replace l.memo (lib, path) k;
          k)
  | _ -> (
      match Hashtbl.find_opt memo (root, lib, path) with
      | Some k -> k
      | None ->
          let k = compute () in
          Hashtbl.replace memo (root, lib, path) k;
          k)

let pp ppf = function
  | Abstract -> Fmt.string ppf "abstract"
  | Transparent members ->
      Fmt.pf ppf "transparent (%d members)" (List.length members)
  | Unknown -> Fmt.string ppf "unknown"
