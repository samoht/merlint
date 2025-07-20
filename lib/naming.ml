(** Naming convention utilities *)

(* Helper to detect if a string is all uppercase *)
let is_all_upper s =
  String.length s > 0 && String.for_all (fun c -> c < 'a' || c > 'z') s

(* Helper to detect word boundaries and split into words *)
let split_words name =
  let len = String.length name in
  let words = ref [] in
  let current_word = Buffer.create 10 in

  let is_upper c = c >= 'A' && c <= 'Z' in
  let is_lower c = c >= 'a' && c <= 'z' in

  (* Count trailing uppercase letters *)
  let trailing_upper_count =
    let rec count i acc =
      if i < 0 then acc
      else if is_upper name.[i] then count (i - 1) (acc + 1)
      else acc
    in
    count (len - 1) 0
  in

  for i = 0 to len - 1 do
    let c = name.[i] in
    let prev = if i > 0 then Some name.[i - 1] else None in
    let next = if i < len - 1 then Some name.[i + 1] else None in

    (* Check for word boundary *)
    let at_boundary =
      match (prev, next) with
      | Some p, _ when is_lower p && is_upper c ->
          true (* camelCase boundary: aB *)
      | Some p, Some n when is_upper p && is_upper c && is_lower n ->
          (* Don't split if:
             1. We're at position 1 (preserves 2-letter uppercase prefix like OCaml)
             2. We're in the trailing uppercase section *)
          if i = 1 then false
          else if i >= len - trailing_upper_count then false
          else true (* Otherwise split: XMLParser -> XML, Parser *)
      | _ -> false
    in

    if at_boundary && Buffer.length current_word > 0 then (
      words := Buffer.contents current_word :: !words;
      Buffer.clear current_word);

    Buffer.add_char current_word c
  done;

  if Buffer.length current_word > 0 then
    words := Buffer.contents current_word :: !words;

  List.rev !words

let to_capitalized_snake_case name =
  (* Convert PascalCase to Snake_case (for modules/variants/constructors) *)
  let len = String.length name in
  if len = 0 then ""
  else if is_all_upper name && not (String.contains name '_') then
    (* All uppercase like "XML" or "III" - keep as is *)
    name
  else if String.contains name '_' then
    (* Already has underscores - keep as is *)
    name
  else
    let words = split_words name in
    match words with
    | [] -> ""
    | [ single ] -> single
    | first :: rest ->
        (* First word: keep capitalization *)
        (* Rest: lowercase each word unless it's all uppercase (acronym) *)
        let converted_rest =
          List.map
            (fun w ->
              if is_all_upper w then w (* Keep acronyms uppercase *)
              else String.lowercase_ascii w)
            rest
        in
        String.concat "_" (first :: converted_rest)

let to_lowercase_snake_case name =
  (* Convert any case to lowercase_snake_case (for values/types/fields) *)
  (* Use same rules as to_capitalized_snake_case, then lowercase everything *)
  let snake_case = to_capitalized_snake_case name in
  String.lowercase_ascii snake_case

let is_pascal_case name =
  String.length name > 0
  && name.[0] >= 'A'
  && name.[0] <= 'Z'
  && not (String.contains name '_')
