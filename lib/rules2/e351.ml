(** E351: Global Mutable State - Example of new self-contained rule *)

open Rule
open Issue

let format_issue = function
  | Mutable_state { kind; name } ->
      Fmt.str "%s '%s' introduces mutable state" 
        (String.capitalize_ascii kind) name
  | _ -> failwith "E351: unexpected issue data"

(* Precompiled regexes for efficiency *)
let ref_type_re = Re.compile (Re.alt [ Re.str " ref"; Re.str "= ref" ])
let array_type_re = Re.compile (Re.str " array")

(** Check if a type signature indicates mutable state *)
let is_mutable_type type_sig =
  (* Skip function types that return refs/arrays *)
  if Re.execp (Re.compile (Re.str "->")) type_sig then false
  else
    (* Check for ref types - look for patterns like "int ref" or "= ref" *)
    Re.execp ref_type_re type_sig
    (* Check for array types *)
    || Re.execp array_type_re type_sig

(** Check outline for global mutable state *)
let check_global_mutable_state ~filename outline =
  List.filter_map
    (fun item ->
      match item.Outline.kind with
      | Outline.Value -> (
          match
            (item.type_sig, Traverse.extract_outline_location filename item)
          with
          | Some type_sig, Some location when is_mutable_type type_sig ->
              let kind =
                if Re.execp ref_type_re type_sig then "ref"
                else if Re.execp array_type_re type_sig then "array"
                else "mutable"
              in
              Some (Issue.create 
                      ~rule_id:Mutable_state 
                      ~location 
                      ~data:(Mutable_state { kind; name = item.name }))
          | _ -> None)
      | _ -> None)
    outline

let check_file (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  check_global_mutable_state ~filename outline_data

let rule =
  v
    ~id:Mutable_state
    ~title:"Global Mutable State"
    ~category:Rule.Style_modernization
    ~hint:"This issue warns about global mutable state which makes code harder to test \
           and reason about. Local mutable state within functions is perfectly acceptable \
           in OCaml. Fix by either using local refs within functions, or preferably by \
           using functional approaches with explicit state passing."
    ~examples:[
      bad "let counter = ref 0\nlet incr_counter () = counter := !counter + 1";
      bad "let global_cache = Array.make 100 None";
      good "let compute_sum lst =\n  let sum = ref 0 in\n  List.iter (fun x -> sum := !sum + x) lst;\n  !sum";
      good "let incr_counter counter = counter + 1";
    ]
    ~check:(File_check check_file)
    ~format_issue
    ()