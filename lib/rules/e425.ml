open Examples
(** E425: Type Documentation Bound to a Constructor *)

type payload = { type_name : string; constructor : string }

(* A variant declaration has no closing delimiter, so a doc comment written
   after the last constructor binds to that constructor, not to the type. The
   author's intent is invisible in the source: [type t = A | B (** ... *)]
   reads as documentation for [t] but odoc renders it under [B], leaving [t]
   undocumented. Records and polymorphic variants close with [}] or []], so a
   trailing comment there binds to the type and is not affected.

   The tell is the shape of the docs: a variant whose only documented
   constructor is the last one, on a type that carries no documentation of its
   own. A type documented before its declaration, or a variant where earlier
   constructors are documented too, is doing per-constructor documentation on
   purpose.

   The shape also catches the case where the comment really was about the last
   constructor and the type simply has no doc at all. That is the same fix seen
   from the other side: give the type a doc comment before its declaration, and
   the constructor's own doc is unambiguous again. *)

let is_constructor item =
  File_view.Item.equal_kind (File_view.Item.kind item)
    File_view.Item.Constructor

let constructors item =
  List.filter is_constructor (File_view.Item.children item)

let documented item = Option.is_some (File_view.Item.doc item)

let rec split_last = function
  | [] -> None
  | [ last ] -> Some ([], last)
  | item :: rest ->
      Option.map
        (fun (earlier, last) -> (item :: earlier, last))
        (split_last rest)

let misbound_doc item =
  match split_last (constructors item) with
  | None -> None
  | Some (earlier, last) ->
      if List.exists documented earlier then None
      else Option.map (fun doc -> (last, doc)) (File_view.Item.doc last)

let check_type item =
  if documented item then []
  else
    match misbound_doc item with
    | None -> []
    | Some (last, doc) ->
        [
          Issue.v ~loc:(File_view.Doc.loc doc)
            {
              type_name = File_view.Item.name item;
              constructor = File_view.Item.name last;
            };
        ]

let is_type item =
  File_view.Item.equal_kind (File_view.Item.kind item) File_view.Item.Type

(* Doc comments live in the artefact the compiler wrote; a typedtree
     typechecked from source carries none, so every declaration would look
     undocumented. Skip the file rather than report an absence nobody can see;
     the engine reports it as not fully examined. *)
let check (ctx : Context.file) =
  if not (File_kind.is_mli (Context.filename ctx)) then []
  else if not (File_view.docs_recorded (Context.view ctx)) then []
  else
    Context.view ctx |> File_view.all_items |> List.filter is_type
    |> List.concat_map check_type

let pp ppf { type_name; constructor } =
  Fmt.pf ppf
    "Type '%s' has no documentation: the comment after its last constructor \
     documents '%s'. Put the type's doc before 'type %s'"
    type_name constructor type_name

let rule =
  Rule.v ~code:"E425" ~title:"Type Documentation Bound to a Constructor"
    ~category:Documentation
    ~hint:
      "A variant declaration has no closing delimiter, so a doc comment placed \
       after the last constructor attaches to that constructor: odoc renders \
       the type's description under one case and the type itself stays \
       undocumented. Put the type's documentation before the declaration, on \
       the line above 'type'. If the comment really does describe that last \
       constructor, the type is simply undocumented: give it its own doc \
       comment before the declaration and the constructor's doc becomes \
       unambiguous. Documentation written after the declaration is safe for \
       records, aliases and abstract types, which end with a delimiter."
    ~examples:[ Example.bad E425.bad_mli; Example.good E425.good_mli ]
    ~pp (File check)
