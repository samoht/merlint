(** E100: No Obj.magic - Example of new self-contained rule *)

open Rule
open Issue

let format_issue = function
  | No_obj_magic -> "Use of Obj.magic (unsafe type casting)"
  | _ -> failwith "E100: unexpected issue data"

let check_file (ctx : Context.file) =
  let ast_data = Context.ast ctx in
  
  (* Check identifiers for Obj.magic usage *)
  Traverse.check_function_usage ast_data.identifiers "Obj" "magic" (fun ~loc ->
      Issue.create ~rule_id:Obj_magic ~location:loc ~data:No_obj_magic)

let rule =
  v
    ~id:Obj_magic
    ~title:"No Obj.magic"
    ~category:Rule.Security_safety
    ~hint:"This issue means you're using Obj.magic, which completely bypasses \
           OCaml's type system and can lead to segfaults and memory corruption. \
           Fix it by using proper type-safe alternatives: option types, variants, \
           GADTs, or redesign your API to avoid the need for type casting."
    ~examples:[
      bad "let convert_anything x = (Obj.magic x : int)";
      bad "Stdlib.Obj.magic";
      good "let safe_convert = function\n  | Some x -> x\n  | None -> 0";
      good "type 'a typed_value = Int : int typed_value | String : string typed_value";
    ]
    ~check:(File_check check_file)
    ~format_issue
    ()