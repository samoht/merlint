(** E351: Detection of global mutable state patterns.

    Reads [Context.dump.value_sigs] (populated by [Merlin.Dump] from the
    typedtree text of the [.mli]) and flags [val x : T] declarations whose outer
    type path resolves to [Stdlib.ref] or [Stdlib.array].

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

let is_stdlib_mutable (path : Merlin.Dump.name) =
  match path.prefix with
  | [ "Stdlib" ] ->
      if path.base = "ref" then Some "ref"
      else if path.base = "array" then Some "array"
      else None
  | _ -> None

let check (ctx : Context.file) =
  if not (String.ends_with ~suffix:".mli" ctx.filename) then []
  else
    let dump = Context.dump ctx in
    List.filter_map
      (fun (s : Merlin.Dump.value_sig) ->
        match (s.type_path, s.location) with
        | Some path, Some loc -> (
            match is_stdlib_mutable path with
            | None -> None
            | Some kind ->
                Some
                  (Issue.v ~loc
                     { kind; name = Merlin.Dump.name_to_string s.name }))
        | _ -> None)
      dump.value_sigs

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
