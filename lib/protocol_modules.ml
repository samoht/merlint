(** Shared protocol state-machine vocabulary, used by E946-E949.

    A protocol's state machine lives in a module named from a closed vocabulary:
    [State] (symmetric, one role) or a role name (asymmetric). The same
    vocabulary is documented in the ocaml-protocols skill's "role vocabulary"
    section; the two are kept in sync. *)

module P = Project_index.Package

(* The recognised complementary role pairs for asymmetric protocols. *)
let role_pairs =
  [
    ("client", "server");
    ("sender", "receiver");
    ("initiator", "responder");
    ("requester", "responder");
  ]

let roles =
  List.sort_uniq compare (List.concat_map (fun (a, b) -> [ a; b ]) role_pairs)

(* Lowercased module basename with any extension stripped. *)
let normalize b =
  let b = Filename.basename b in
  let b = try Filename.chop_extension b with Invalid_argument _ -> b in
  String.lowercase_ascii b

let is_state_machine_name b =
  let b = normalize b in
  b = "state" || List.mem b roles

(* A package whose state machines do not use the default role vocabulary
   declares their module basenames in [allowed_states] in its [merlint.toml].
   Those are recognised as state machines in addition to the vocabulary. *)
let declared_states pkg =
  match P.source_dir pkg with
  | Some dir ->
      List.map normalize (Config.load (Fpath.to_string dir)).allowed_states
  | None -> []

let is_state_machine ~declared b =
  let b = normalize b in
  b = "state" || List.mem b roles || List.mem b declared

(* The protocol core is I/O-free (E930); an [eio]-tagged sibling is the adapter
   that wires the core's state machine into I/O, so it is out of scope. *)
let is_protocol_pkg pkg =
  let tags = P.tags pkg in
  List.mem "protocol" tags && not (List.mem "eio" tags)

(* The [.ml] module basenames of a package's libraries. *)
let module_basenames pkg =
  Project_index.package_libraries pkg
  |> List.concat_map Project_index.Library.files
  |> List.filter_map (fun f ->
      if Fpath.has_ext ".ml" f then Some (normalize (Fpath.basename f))
      else None)

let exposes_state_machine pkg =
  let bs = module_basenames pkg in
  let has m = List.mem m bs in
  has "state"
  || List.exists (fun (a, b) -> has a && has b) role_pairs
  || List.exists has (declared_states pkg)

type machine_module = {
  package : string;
  module_name : string;
  file : Context.path;
}

let state_machine_modules ctx pkg =
  let declared = declared_states pkg in
  Project_index.package_libraries pkg
  |> List.concat_map Project_index.Library.files
  |> List.filter_map (fun f ->
      if Fpath.has_ext ".ml" f && is_state_machine ~declared (Fpath.basename f)
      then
        Some
          {
            package = P.name pkg;
            module_name = normalize (Fpath.basename f);
            file = Context.resolve ctx f;
          }
      else None)

let protocol_machine_modules ctx =
  Context.index ctx |> Project_index.source_package_list
  |> List.filter is_protocol_pkg
  |> List.concat_map (state_machine_modules ctx)
