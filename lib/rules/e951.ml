(** E951: Exhaustive message match.

    A protocol state machine dispatches on the message it just received. When
    that [match] has a catch-all wildcard arm ([| _ -> ...] or [| m -> ...])
    whose body returns a normal value -- [Ok _], a tuple, a record, a state
    value, or [()] -- it silently ACCEPTS an unexpected message instead of
    rejecting it. That is the nqsb-tls / "Messy State of the Union" (USENIX
    2015) bug: the FREAK/SKIP-class flaws came from a state machine that fell
    through to a normal transition on a message it had no business accepting.

    This rule flags, in a state-machine module (see {!Protocol_modules}), a
    [match] whose scrutinee's type is the protocol message type (its path has a
    [Message] component, e.g. [Ssh.Message.t]) and whose wildcard arm is a clear
    accept. Rejecting the message at the value level ([| _ -> Error _], or an
    [err "..."] helper that returns an [Error]) is the correct pattern and is
    not flagged; enumerating every constructor with no wildcard is better still.
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
    "%s matches on the message type with a wildcard arm that silently accepts \
     an unexpected message (it returns a normal value). A protocol transition \
     rejects an unexpected message at the value level (Error _), or enumerates \
     every message constructor with no catch-all."
    (String.capitalize_ascii module_)

let rule =
  Rule.v ~code:"E951" ~title:"Exhaustive message match"
    ~category:Rule.Project_structure
    ~hint:
      "A match over the protocol message type must not silently accept an \
       unexpected message with a wildcard arm that returns a normal value (Ok \
       _, a tuple, a record, a state value, unit). Reject it by returning an \
       Error, or enumerate every message constructor. See E946-E950 and E952 \
       for the rest of the protocol shape."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
