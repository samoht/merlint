(** E951: Exhaustive message match.

    A protocol state machine dispatches on the message it just received. The
    OCaml-native way to keep that dispatch exhaustive is to enumerate every
    message constructor: then adding a constructor to the message type is a
    compile error at every match that does not handle it, forcing a review. A
    catch-all [| _ -> ...] arm defeats that -- the new constructor silently
    falls through the wildcard instead. That is the nqsb-tls / "Messy State of
    the Union" (USENIX 2015) bug: the FREAK/SKIP-class flaws came from state
    machines that mishandled messages they should have rejected.

    This rule flags, in a state-machine module (see {!Protocol_modules}), a
    [match] whose scrutinee's type is the protocol message type (its path has a
    [Message] component, e.g. [Ssh.Message.t]) and that has a catch-all wildcard
    arm. The arm body is irrelevant: even [| _ -> Error _] is flagged, because
    the wildcard still defeats the exhaustiveness check. Enumerate the
    constructors instead (group them, [| Foo | Bar -> Error "unexpected"], to
    share a rejection). This is the message-scoped sibling of OCaml's
    fragile-match warning (warning 4), narrowed to the dispatch that matters.
    See E946-E950 and E952 for the rest of the protocol shape. *)

module FV = File_view

type payload = { module_ : string }

let check (ctx : Context.project) (m : Protocol_modules.machine_module) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        let issues = ref [] in
        FV.iter_message_matches view (fun mm ->
            let loc = FV.Message_match.loc mm in
            issues := Issue.v ~loc { module_ = m.module_name } :: !issues);
        List.rev !issues

let enumerate ctx = Protocol_modules.protocol_machine_modules ctx

let pp ppf { module_ } =
  Fmt.pf ppf
    "%s matches on the message type with a catch-all wildcard arm. The \
     wildcard defeats the compiler's exhaustiveness check -- a message \
     constructor added later silently falls through it. Enumerate every \
     constructor (group them to share a rejection) so the type-checker flags \
     every match when the message type grows."
    (String.capitalize_ascii module_)

let rule =
  Rule.v ~code:"E951" ~title:"Exhaustive message match"
    ~category:Rule.Project_structure
    ~hint:
      "A match over the protocol message type must not use a catch-all \
       wildcard arm (| _ -> ...): it defeats the compiler's exhaustiveness \
       check, so a new message constructor silently falls through instead of \
       forcing a review. Enumerate every constructor (group them to share a \
       rejection). See E946-E950 and E952 for the rest of the protocol shape."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
