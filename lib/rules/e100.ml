(** E100: No Obj.magic *)

let check ctx =
  let dump_data = Context.dump ctx in

  (* Check identifiers for Obj.magic usage *)
  Dump.check_function_usage dump_data.identifiers "Obj" "magic" (fun ~loc ->
      Issue.v ~loc ())

let pp ppf () =
  Fmt.pf ppf "Usage of Obj.magic detected - this is extremely unsafe"

let rule =
  Rule.v ~code:"E100" ~title:"No Obj.magic" ~category:Security_safety
    ~hint:
      "Obj.magic completely bypasses OCaml's type system and is extremely \
       dangerous. It can lead to segmentation faults, data corruption, and \
       unpredictable behavior. Instead, use proper type definitions, GADTs, or \
       polymorphic variants. If you absolutely must use unsafe features, \
       document why and isolate the usage."
    ~examples:[] ~pp (File check)
