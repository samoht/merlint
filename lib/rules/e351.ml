(** E351: Detection of global mutable state patterns.

    Reads native typedtree value signatures and flags [val x : T] declarations
    whose outer type path resolves to [Stdlib.ref] or the compiler primitive
    [array].

    Because the path comes from the typed tree, a local definition like

    {[
    type 'a ref = 'a list

    val x : int ref
    ]}

    does {e not} trip the rule: the local [ref] has [prefix = []] while the
    stdlib one has [prefix = ["Stdlib"]]. Wraps like [val y : t array cons] are
    also skipped -- the outer path is [cons], not [array]. *)

type payload = { kind : string; name : string }
(** Payload for mutable state issues *)

let is_stdlib_mutable path =
  match (File_view.Name.prefix path, File_view.Name.base path) with
  | [ "Stdlib" ], "ref" -> Some "ref"
  | [ "Stdlib" ], "array" | [], "array" -> Some "array"
  | _ -> None

let check (ctx : Context.file) =
  if not (File_kind.is_mli (Context.filename ctx)) then []
  else
    let view = Context.view ctx in
    List.filter_map
      (fun s ->
        match (File_view.Value_sig.type_path s, File_view.Value_sig.loc s) with
        | Some path, Some loc -> (
            match is_stdlib_mutable path with
            | None -> None
            | Some kind ->
                Some
                  (Issue.v ~loc
                     {
                       kind;
                       name =
                         File_view.Name.to_string (File_view.Value_sig.name s);
                     }))
        | _ -> None)
      (Option.value ~default:[] (File_view.resolved_signatures view))

let pp ppf { kind; name } =
  Fmt.pf ppf
    "Exposed global mutable state '%s' of type '%s' in interface - instead of \
     exposing mutable state, consider providing functions that encapsulate the \
     state manipulation"
    name kind

let rule =
  Rule.v ~code:"E351" ~title:"Exposed Global Mutable State"
    ~category:Security_safety
    ~hint:
      "Exposing global mutable state in interfaces (.mli files) breaks \
       encapsulation and makes programs harder to reason about. Instead of \
       exposing refs or mutable arrays directly, provide functions that \
       encapsulate state manipulation. This preserves module abstraction and \
       makes the API clearer. Internal mutable state in .ml files is fine as \
       long as it's not exposed in the interface."
    ~examples:
      [ Example.bad Examples.E351.bad_ml; Example.good Examples.E351.good_ml ]
    ~pp (File check)
