# Implementation Plan for New Rules

## E350: Boolean Blindness Detection

### Detection Logic
```ocaml
(* In lib/api_design.ml *)
let check_boolean_blindness ~outline =
  match outline with
  | None -> []
  | Some items ->
      List.filter_map (fun (item : Outline.item) ->
        match item.type_sig with
        | Some sig_str ->
            let bool_count = count_bool_params sig_str in
            if bool_count >= 2 then
              Some (Issue.Boolean_blindness {
                function_name = item.name;
                location = extract_location item;
                bool_count;
                signature = sig_str;
              })
            else None
        | None -> None
      ) items

let count_bool_params type_sig =
  (* Count occurrences of "bool ->" in the signature *)
  let rec count acc remaining =
    match String.find_sub ~sub:"bool ->" remaining with
    | exception Not_found -> acc
    | pos ->
        let next_start = pos + 7 in
        if next_start < String.length remaining then
          count (acc + 1) (String.sub remaining next_start 
            (String.length remaining - next_start))
        else acc + 1
  in
  count 0 type_sig
```

### Example Detection
```ocaml
(* Would flag these: *)
val create_window : bool -> bool -> bool -> window
val configure : ?visible:bool -> ?resizable:bool -> unit -> unit

(* Would not flag: *)
val is_valid : t -> bool
val create : visibility -> resizability -> window
```

## E351: Mutable State Detection

### Detection Logic
```ocaml
(* In lib/immutability.ml *)
let check_mutable_state typedtree =
  let issues = ref [] in
  
  (* Check for ref usage *)
  List.iter (fun (id : Typedtree.elt) ->
    if id.name.base = "ref" && id.name.prefix = ["Stdlib"] then
      match id.location with
      | Some loc ->
          issues := Issue.Mutable_ref { location = loc } :: !issues
      | None -> ()
  ) typedtree.identifiers;
  
  (* Check for := operator *)
  List.iter (fun (id : Typedtree.elt) ->
    if id.name.base = ":=" then
      match id.location with
      | Some loc ->
          issues := Issue.Mutable_assignment { location = loc } :: !issues
      | None -> ()
  ) typedtree.identifiers;
  
  (* Check for mutable record fields - needs parsetree analysis *)
  (* This would require enhancing our AST extraction *)
  
  !issues
```

## E352: Generic Label Detection

### Detection Logic
```ocaml
(* In lib/api_design.ml *)
let generic_labels = ["f"; "x"; "k"; "v"; "a"; "b"; "fn"; "func"]

let check_generic_labels ~outline =
  match outline with
  | None -> []
  | Some items ->
      List.concat_map (fun (item : Outline.item) ->
        match item.type_sig with
        | Some sig_str ->
            extract_labels sig_str
            |> List.filter_map (fun label ->
                if List.mem label generic_labels then
                  Some (Issue.Generic_label {
                    function_name = item.name;
                    label;
                    location = extract_location item;
                  })
                else None)
        | None -> []
      ) items

let extract_labels type_sig =
  (* Extract ~label: patterns from signature *)
  Re.all (Re.Perl.compile_pat "~([a-z_]+):") type_sig
  |> List.map (fun g -> Re.Group.get g 1)
```

## E353: Modern Concurrency Detection

### Detection Logic
```ocaml
(* In lib/modern_patterns.ml *)
let concurrent_unix_functions = [
  "fork"; "wait"; "waitpid"; "pipe"; "socketpair"; 
  "create_process"; "open_process"; "establish_server"
]

let check_unix_concurrency typedtree =
  List.filter_map (fun (id : Typedtree.elt) ->
    match id.name with
    | { prefix = ["Unix"]; base } when List.mem base concurrent_unix_functions ->
        (match id.location with
        | Some loc ->
            Some (Issue.Unix_concurrency {
              function_name = base;
              location = loc;
            })
        | None -> None)
    | _ -> None
  ) typedtree.identifiers
```

## Integration Steps

1. **Add Issue Types** to `lib/issue_type.ml`:
   ```ocaml
   | Boolean_blindness
   | Mutable_ref  
   | Mutable_assignment
   | Generic_label
   | Unix_concurrency
   ```

2. **Add Issue Constructors** to `lib/issue.ml`

3. **Create New Check Modules**:
   - `lib/api_design.ml` - for E350 and E352
   - `lib/immutability.ml` - for E351
   - `lib/modern_patterns.ml` - for E353

4. **Wire into Rules System** in `lib/rules.ml`

5. **Add Tests** for each new rule

6. **Update Documentation** in `lib/data.ml`

## Priority Order

1. **E350 (Boolean Blindness)** - Easiest to implement, high impact
2. **E352 (Generic Labels)** - Simple string matching on signatures
3. **E351 (Mutable State)** - Partially implementable with current AST
4. **E353 (Unix Concurrency)** - Requires careful function list curation