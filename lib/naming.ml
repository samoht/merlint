(** Naming convention utilities *)

(* Helper to detect if a string is all uppercase *)
let is_all_upper s =
  String.length s > 0 && String.for_all (fun c -> c < 'a' || c > 'z') s

let is_upper c = c >= 'A' && c <= 'Z'
let is_lower c = c >= 'a' && c <= 'z'

(* Count trailing uppercase letters in a string *)
let trailing_upper_count name =
  let rec count i acc =
    if i < 0 then acc
    else if is_upper name.[i] then count (i - 1) (acc + 1)
    else acc
  in
  count (String.length name - 1) 0

(* Helper to detect word boundaries and split into words *)
let entering_trailing_acronym ~len ~trailing i =
  i >= len - trailing && trailing <= 2

let leaving_acronym ~len ~trailing i = i <> 1 && i < len - trailing

let at_word_boundary ~len ~trailing i c prev next =
  match (prev, next) with
  | Some p, _ when is_lower p && is_upper c ->
      (* Don't split when entering a short trailing acronym (<= 2 chars).
         These form compound terms in English: MacOS, WebGL, OpenAI.
         Longer acronyms (XML, API, SDK) are separate words. *)
      not (entering_trailing_acronym ~len ~trailing i)
  | Some p, Some n when is_upper p && is_upper c && is_lower n ->
      (* Preserve two-letter uppercase prefixes like OCaml and trailing
         acronyms; otherwise split: XMLParser -> XML, Parser. *)
      leaving_acronym ~len ~trailing i
  | _ -> false

let split_words name =
  let len = String.length name in
  let words = ref [] in
  let current_word = Buffer.create 10 in
  let trailing = trailing_upper_count name in

  for i = 0 to len - 1 do
    let c = name.[i] in
    let prev = if i > 0 then Some name.[i - 1] else None in
    let next = if i < len - 1 then Some name.[i + 1] else None in

    let at_boundary = at_word_boundary ~len ~trailing i c prev next in

    if at_boundary && Buffer.length current_word > 0 then (
      words := Buffer.contents current_word :: !words;
      Buffer.clear current_word);

    Buffer.add_char current_word c
  done;

  if Buffer.length current_word > 0 then
    words := Buffer.contents current_word :: !words;

  List.rev !words

let snake_case_of_words = function
  | [] -> ""
  | [ single ] -> single
  | first :: rest ->
      (* Keep the first word's capitalisation; lowercase the rest except
         acronyms (kept uppercase). *)
      let converted_rest =
        List.map
          (fun w -> if is_all_upper w then w else String.lowercase_ascii w)
          rest
      in
      String.concat "_" (first :: converted_rest)

let to_capitalized_snake_case name =
  (* Convert PascalCase to Snake_case (for modules/variants/constructors) *)
  if String.length name = 0 then ""
  else if is_all_upper name && not (String.contains name '_') then
    (* All uppercase like "XML" or "III" - keep as is *)
    name
  else if String.contains name '_' then
    (* Already has underscores - keep as is *)
    name
  else snake_case_of_words (split_words name)

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
