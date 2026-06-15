(** E946: Protocols expose a state machine.

    A protocol package (tagged [protocol]) is a codec plus an I/O-free state
    machine -- that state machine is the package's primary concern. It must live
    in a named module: [Protocol], or [Client] / [Server] for asymmetric
    protocols where who-initiates matters. A protocol package with no such
    module is missing its defining layer (it is then only a codec, and should
    drop the [protocol] tag, or it has hidden the state machine somewhere
    unfindable).

    This checks the module is present; that it is *pure* (no eio/lwt/unix in the
    core library) is E930, and that the AST does not depend on the codec is
    E945. *)

module P = Project_index.Package
module L = Project_index.Library

(* The protocol core is I/O-free (E930); an [eio]-tagged sibling is the adapter
   that wires the core's state machine into I/O and has none of its own, so it
   is out of scope. *)
let is_protocol_pkg pkg =
  let tags = P.tags pkg in
  List.mem "protocol" tags && not (List.mem "eio" tags)

(* Source-file module basenames of a library (so it works on in-repo source
   libraries, where the installed-metadata module list is empty). *)
let module_basenames lib =
  List.filter_map
    (fun f ->
      let b = Fpath.basename f in
      if Filename.check_suffix b ".ml" then
        Some (String.lowercase_ascii (Filename.chop_suffix b ".ml"))
      else None)
    (L.files lib)

(* A protocol's state machine lives in [Protocol], or in [Client] + [Server] for
   asymmetric protocols (the protocols skill's two shapes). *)
let exposes_state_machine pkg =
  List.exists
    (fun lib ->
      let ms = module_basenames lib in
      let has m = List.mem m ms in
      has "protocol" || (has "client" && has "server"))
    (Project_index.package_libraries pkg)

type payload = { package : string }

let opam_path pkg =
  match P.opam_path pkg with
  | Some path -> Fpath.to_string (Loc.current_dir_relative path)
  | None -> P.name pkg ^ ".opam"

let check_package pkg =
  if (not (is_protocol_pkg pkg)) || exposes_state_machine pkg then []
  else
    let opam = opam_path pkg in
    [ Issue.v ~loc:(Location.in_file opam) { package = P.name pkg } ]

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.concat_map check_package

let pp ppf { package } =
  Fmt.pf ppf
    "%s is tagged protocol but exposes no state-machine module. A protocol is \
     a codec plus an I/O-free state machine; put it in a Protocol module (or \
     Client / Server for asymmetric protocols)."
    package

let rule =
  Rule.v ~code:"E946" ~title:"Protocol state machine"
    ~category:Rule.Project_structure
    ~hint:
      "A protocol package (tagged protocol) is a codec plus an I/O-free state \
       machine. Expose that state machine as a Protocol module, or Client / \
       Server for asymmetric protocols. Purity of the core is E930; AST/codec \
       layering is E945."
    ~examples:[] ~pp (Project check)
