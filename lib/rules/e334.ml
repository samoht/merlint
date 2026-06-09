(** E334: Redundant Variant/Field Prefixes *)

type case_kind = Constructor | Field

type payload = {
  case_kind : case_kind;
  name : string;
  prefix : string;
  type_name : string;
  suggested : string;
}

let is_letter c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
let words name = String.split_on_char '_' name

(* OCaml reserved keywords cannot be used as field names, so a record field whose
   bare form would be a keyword (e.g. [entity_type] -> [type]) takes a trailing
   underscore instead ([type_]). Constructors are capitalized and never collide. *)
let reserved =
  [
    "and";
    "as";
    "assert";
    "asr";
    "begin";
    "class";
    "constraint";
    "do";
    "done";
    "downto";
    "else";
    "end";
    "exception";
    "external";
    "false";
    "for";
    "fun";
    "function";
    "functor";
    "if";
    "in";
    "include";
    "inherit";
    "initializer";
    "land";
    "lazy";
    "let";
    "lor";
    "lsl";
    "lsr";
    "lxor";
    "match";
    "method";
    "mod";
    "module";
    "mutable";
    "new";
    "nonrec";
    "object";
    "of";
    "open";
    "or";
    "private";
    "rec";
    "sig";
    "struct";
    "then";
    "to";
    "true";
    "try";
    "type";
    "val";
    "virtual";
    "when";
    "while";
    "with";
  ]

(* Number of leading underscore-separated words shared by every name. Words are
   compared whole, so [Apple] and [Apricot] share nothing (no [_] boundary)
   while [Foo_bar] and [Foo_baz] share [Foo]. The result is capped at one below
   the shortest name's word count so stripping always leaves at least one word
   behind. *)
let common_word_prefix names =
  match List.map (fun n -> Array.of_list (words n)) names with
  | [] | [ _ ] -> 0
  | first :: rest ->
      let shortest =
        List.fold_left
          (fun acc w -> min acc (Array.length w))
          (Array.length first) rest
      in
      let rec count i =
        if i >= shortest then i
        else if List.for_all (fun w -> w.(i) = first.(i)) rest then count (i + 1)
        else i
      in
      min (count 0) (shortest - 1)

let suggested case_kind remainder =
  let s = String.concat "_" remainder in
  match case_kind with
  | Constructor -> String.capitalize_ascii s
  | Field -> if List.mem s reserved then s ^ "_" else s

let case_kind_of item =
  match File_view.Item.kind item with
  | File_view.Item.Constructor -> Some Constructor
  | File_view.Item.Field -> Some Field
  | _ -> None

(* The remainder is what survives stripping the shared prefix. It is usable as a
   replacement only when it starts with a letter: a numeric tail ([V_1] -> [1])
   would not be a valid constructor or field, so the whole type is left alone. *)
let valid_remainder = function
  | w :: _ -> String.length w > 0 && is_letter w.[0]
  | [] -> false

let check_type allowed (ty : File_view.Item.t) =
  let type_name = File_view.Item.name ty in
  let cases =
    List.filter_map
      (fun child -> Option.map (fun k -> (k, child)) (case_kind_of child))
      (File_view.Item.children ty)
  in
  match cases with
  | [] | [ _ ] -> []
  | _ ->
      let names = List.map (fun (_, c) -> File_view.Item.name c) cases in
      let k = common_word_prefix names in
      if k < 1 then []
      else
        let remainders =
          List.map (fun n -> List.filteri (fun i _ -> i >= k) (words n)) names
        in
        if not (List.for_all valid_remainder remainders) then []
        else
          let prefix =
            String.concat "_"
              (List.filteri (fun i _ -> i < k) (words (List.hd names)))
            ^ "_"
          in
          List.map2
            (fun (case_kind, child) remainder ->
              let name = File_view.Item.name child in
              if List.mem name allowed then None
              else
                let loc = File_view.Item.loc child in
                Some
                  (Issue.v ~loc
                     {
                       case_kind;
                       name;
                       prefix;
                       type_name;
                       suggested = suggested case_kind remainder;
                     }))
            cases remainders
          |> List.filter_map Fun.id

let check (ctx : Context.file) =
  let allowed = ctx.config.allowed_words in
  File_view.all_items (Context.view ctx)
  |> List.filter (fun item -> File_view.Item.kind item = File_view.Item.Type)
  |> List.concat_map (check_type allowed)

let pp ppf { case_kind; name; prefix; type_name; suggested } =
  let what, group =
    match case_kind with
    | Constructor -> ("Constructor", "constructors")
    | Field -> ("Field", "fields")
  in
  Fmt.pf ppf
    "%s '%s' shares redundant prefix '%s' with all %s of type '%s' - consider \
     '%s' (type disambiguation handles the rest at call sites)"
    what name prefix group type_name suggested

let rule =
  Rule.v ~code:"E334" ~title:"Redundant Variant/Field Prefixes"
    ~category:Naming_conventions
    ~hint:
      "When every constructor of a variant, or every field of a record, starts \
       with the same prefix, that prefix is redundant: the type already names \
       the concept and OCaml's type-directed disambiguation resolves the bare \
       name at call sites. Drop the shared prefix (type foo = Bar | Baz, not \
       Foo_bar | Foo_baz; { bar; baz }, not { foo_bar; foo_baz }). When a bare \
       field would be an OCaml keyword the convention is a trailing underscore \
       (entity_type -> type_). Keep a prefix only when a bare case would be a \
       spec-mandated name listed in allowed_words."
    ~examples:
      [ Example.bad Examples.E334.bad_ml; Example.good Examples.E334.good_ml ]
    ~pp (File check)
