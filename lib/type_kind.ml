(** Classify a cross-module type as abstract or transparent by reading its
    declaring module's [.cmti]. Pure: uses [Cmt_format.read_cmt] only, never
    [Env] / [Load_path] global state. *)

module Cmt = Ocaml_typing.Cmt_format
module T = Ocaml_typing.Typedtree
module Types = Ocaml_typing.Types
module Ident = Ocaml_typing.Ident

type t = Abstract | Transparent of Types.type_expr list | Unknown

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
      let install = Filename.concat root "_build/install/default/lib" in
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
  | Types.Type_abstract _ | Types.Type_open | Types.Type_external _ -> (
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
let rec resolve_module ~fuel index module_path mods name =
  if fuel <= 0 then Unknown
  else
    match module_path with
    | [] -> Unknown
    | first :: rest ->
        let lib = mangle_lib first in
        let nav = rest @ mods in
        let rec try_depth taken remaining =
          let mangled =
            collapse_underscores (String.concat "__" (lib :: List.rev taken))
          in
          let here =
            match Hashtbl.find_opt index mangled with
            | Some cmti -> read_cmti ~fuel index cmti remaining name
            | None -> Unknown
          in
          match (here, remaining) with
          | Unknown, m :: more -> try_depth (m :: taken) more
          | k, _ -> k
        in
        try_depth [] nav

and read_cmti ~fuel index cmti mods name =
  match Cmt.read_cmt cmti with
  | exception _ -> Unknown
  | cmt -> (
      match cmt.Cmt.cmt_annots with
      | Cmt.Interface sg -> resolve_in_sig ~fuel index sg mods name
      | Cmt.Implementation str -> resolve_in_str ~fuel index str mods name
      | _ -> Unknown)

(* Same as [resolve_in_sig], but over a [.cmt] implementation's structure, for
   modules that ship no [.mli] (their inferred interface is the structure). An
   [include M] brings M's items into this module ([Tstr_include]); search its
   expanded signature so a type re-exported that way still resolves. *)
and resolve_in_str ~fuel index (str : T.structure) mods name =
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
        Some (resolve_in_mod ~fuel index mb.mb_expr rest name)
    | T.Tstr_include incl, _ -> (
        match resolve_in_tsig ~fuel index incl.incl_type mods name with
        | Unknown -> None
        | k -> Some k)
    | _ -> None
  in
  Option.value ~default:Unknown (List.find_map from_item str.str_items)

and resolve_in_mod ~fuel index (me : T.module_expr) mods name =
  match me.mod_desc with
  | T.Tmod_structure str -> resolve_in_str ~fuel index str mods name
  | T.Tmod_constraint (me, _, _, _) -> resolve_in_mod ~fuel index me mods name
  | T.Tmod_ident (p, _) ->
      resolve_module ~fuel:(fuel - 1) index (path_parts p) mods name
  | _ -> Unknown

(* Walk into nested submodules [mods] then read the named type's declaration. An
   [include module type of M] (the "_intf trick": the real declarations live in
   an [.ml]-only [M_intf], re-exported here) appears as a single [Tsig_include]
   whose [incl_type] holds the expanded signature; search it so a type or
   submodule surfaced that way still resolves instead of reading as abstract. *)
and resolve_in_sig ~fuel index (sg : T.signature) mods name =
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
        Some (resolve_in_mty ~fuel index md.md_type rest name)
    | T.Tsig_include incl, _ -> (
        match resolve_in_tsig ~fuel index incl.incl_type mods name with
        | Unknown -> None
        | k -> Some k)
    | _ -> None
  in
  Option.value ~default:Unknown (List.find_map from_item sg.sig_items)

and resolve_in_mty ~fuel index (mty : T.module_type) mods name =
  match mty.mty_desc with
  | T.Tmty_signature sg -> resolve_in_sig ~fuel index sg mods name
  (* [module M = N]: M is the module at path N, so resolve N afresh and navigate
     the rest of the chain inside it. *)
  | T.Tmty_alias (p, _) ->
      resolve_module ~fuel:(fuel - 1) index (path_parts p) mods name
  | _ -> Unknown

(* The expanded signature carried by an include is a [Types.signature], not a
   Typedtree one, so it needs its own walk: navigate the remaining submodules
   then read the named type's declaration the same way. *)
and resolve_in_tsig ~fuel index (sg : Types.signature) mods name =
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
      | Some mty -> resolve_in_tmty ~fuel index mty rest name
      | None -> Unknown)

and resolve_in_tmty ~fuel index (mty : Types.module_type) mods name =
  match mty with
  | Types.Mty_signature sg -> resolve_in_tsig ~fuel index sg mods name
  | Types.Mty_alias p ->
      resolve_module ~fuel:(fuel - 1) index (path_parts p) mods name
  | _ -> Unknown

let resolve ~root ~path =
  let index = cmti_index root in
  match List.rev (String.split_on_char '.' path) with
  | type_name :: (_ :: _ as module_rev) ->
      resolve_module ~fuel:10 index (List.rev module_rev) [] type_name
  | _ -> Unknown

let classify ~root ?lib ~path () =
  match Hashtbl.find_opt memo (root, lib, path) with
  | Some k -> k
  | None ->
      let k =
        match (resolve ~root ~path, lib) with
        (* a short sibling that did not resolve on its own: retry it as a
           sub-unit of the enclosing library *)
        | Unknown, Some l -> resolve ~root ~path:(qualify l path)
        | k, _ -> k
      in
      Hashtbl.replace memo (root, lib, path) k;
      k

let pp ppf = function
  | Abstract -> Fmt.string ppf "abstract"
  | Transparent members ->
      Fmt.pf ppf "transparent (%d members)" (List.length members)
  | Unknown -> Fmt.string ppf "unknown"
