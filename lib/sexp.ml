(** Simple S-expression parser for dune files *)

type t = Atom of string | List of t list

let is_atom_char c =
  match c with
  | 'a' .. 'z'
  | 'A' .. 'Z'
  | '0' .. '9'
  | '_' | '-' | '.' | '/' | ':' | '+' | '=' | '<' | '>' | '*' | '?' | '!' ->
      true
  | _ -> false

let skip_whitespace ~content ~len ~pos =
  while !pos < len && String.contains " \t\n\r" content.[!pos] do
    incr pos
  done

let skip_line_comment ~content ~len ~pos =
  while !pos < len && content.[!pos] <> '\n' do
    incr pos
  done;
  if !pos < len then incr pos

let rec skip_whitespace_and_comments ~content ~len ~pos =
  skip_whitespace ~content ~len ~pos;
  if !pos < len && content.[!pos] = ';' then (
    skip_line_comment ~content ~len ~pos;
    skip_whitespace_and_comments ~content ~len ~pos)

let parse_quoted_string ~content ~len ~pos =
  incr pos;
  (* skip opening quote *)
  let buf = Buffer.create 64 in
  while !pos < len && content.[!pos] <> '"' do
    if content.[!pos] = '\\' && !pos + 1 < len then (
      incr pos;
      let c =
        match content.[!pos] with
        | 'n' -> '\n'
        | 't' -> '\t'
        | 'r' -> '\r'
        | c -> c
      in
      Buffer.add_char buf c)
    else Buffer.add_char buf content.[!pos];
    incr pos
  done;
  if !pos < len then incr pos;
  (* skip closing quote *)
  Atom (Buffer.contents buf)

let parse_atom ~content ~len ~pos =
  let start = !pos in
  while !pos < len && is_atom_char content.[!pos] do
    incr pos
  done;
  Atom (String.sub content start (!pos - start))

let rec parse_sexp ~content ~len ~pos =
  skip_whitespace_and_comments ~content ~len ~pos;
  if !pos >= len then None
  else
    match content.[!pos] with
    | '(' ->
        incr pos;
        let items = ref [] in
        skip_whitespace_and_comments ~content ~len ~pos;
        while !pos < len && content.[!pos] <> ')' do
          (match parse_sexp ~content ~len ~pos with
          | Some sexp -> items := sexp :: !items
          | None -> ());
          skip_whitespace_and_comments ~content ~len ~pos
        done;
        if !pos < len then incr pos;
        (* skip closing paren *)
        Some (List (List.rev !items))
    | '"' -> Some (parse_quoted_string ~content ~len ~pos)
    | c when is_atom_char c -> Some (parse_atom ~content ~len ~pos)
    | _ ->
        incr pos;
        parse_sexp ~content ~len ~pos

(** Parse s-expressions from a string *)
let parse_string content =
  let len = String.length content in
  let pos = ref 0 in
  let rec parse_all acc =
    match parse_sexp ~content ~len ~pos with
    | Some sexp -> parse_all (sexp :: acc)
    | None -> acc
  in
  List.rev (parse_all [])
