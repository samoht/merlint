(** E949: One state machine per module.

    A protocol's state machine is one reviewable, learnable unit. An asymmetric
    protocol has one machine per role, and each role is its own top-level module
    from the closed vocabulary ([Client]/[Server], [Sender]/[Receiver], ...) --
    not two machines nested as [module Sender] / [module Receiver] inside a
    single [state.ml].

    This rule flags a state-machine module file (see {!Protocol_modules}) that
    defines more than one state-machine [type t] -- a record or variant [t] at
    the top level, or inside a nested module. The fix is to split each role into
    its own top-level module, both names from the role vocabulary. *)

module FV = File_view

type payload = { module_ : string; roles : string list }

(* A concrete state type: [type t] that is a record or variant (so it has
   children), not an alias or abstract type. *)
let is_machine_type item =
  FV.Item.kind item = FV.Item.Type
  && FV.Item.name item = "t"
  && FV.Item.children item <> []

(* A nested module that itself defines a machine [type t]. *)
let nested_machine item =
  match FV.Item.kind item with
  | FV.Item.Module when List.exists is_machine_type (FV.Item.children item) ->
      Some (FV.Item.name item)
  | _ -> None

let check (ctx : Context.project) (m : Protocol_modules.machine_module) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        let top = FV.typed_items view in
        let nested = List.filter_map nested_machine top in
        let roles =
          if List.exists is_machine_type top then m.module_name :: nested
          else nested
        in
        if List.length roles <= 1 then []
        else
          [
            Issue.v
              ~loc:(Location.in_file (Context.string_of_path m.file))
              { module_ = m.module_name; roles };
          ]

let enumerate ctx = Protocol_modules.protocol_machine_modules ctx

let pp ppf { module_; roles } =
  Fmt.pf ppf
    "%s.ml defines %d state machines (%a); a module holds one state machine. \
     Split each role into its own top-level module (Client/Server, \
     Sender/Receiver, ...), not nested modules in one file."
    module_ (List.length roles)
    Fmt.(list ~sep:(any ", ") string)
    (List.map String.capitalize_ascii roles)

let rule =
  Rule.v ~code:"E949" ~title:"One state machine per module"
    ~category:Rule.Project_structure
    ~hint:
      "A state-machine module holds exactly one state-machine type t. Two \
       roles are two top-level modules (Client/Server, Sender/Receiver, ...), \
       not nested module Sender / module Receiver in one state.ml. See E946 \
       for the module, E947 for immutable state, E948 for verb names."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
