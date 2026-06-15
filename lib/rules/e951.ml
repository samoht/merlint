(** E951: Reject unexpected messages.

    A protocol state machine dispatches on the message it just received. A
    catch-all [| _ -> ...] arm over the message type is fine when it *rejects*
    the unexpected message -- [| _ -> Error "unexpected"], or
    [| s -> Error (`Unexpected s)] to name it. It is a bug when it *silently
    accepts*: the body returns a normal value (an [Ok], a new state, [()]) and
    the machine keeps going on a message it had no business handling. That is
    the nqsb-tls / "Messy State of the Union" (USENIX 2015) flaw: the
    FREAK/SKIP-class attacks came from state machines that fell through to a
    normal transition on an unexpected message.

    This rule flags, in a state-machine module (see {!Protocol_modules}), a
    [match] whose scrutinee's type is the protocol message type (its path has a
    [Message] component, e.g. [Ssh.Message.t]) and whose catch-all arm silently
    accepts. Enumerating the message type instead is impractical when it has
    many constructors; rejecting at the catch-all ([Error _]) is the idiom this
    rule enforces. See E946-E950 and E952 for the rest of the protocol shape. *)

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
    "%s matches on the message type with a catch-all arm that silently accepts \
     an unexpected message (it returns a normal value instead of rejecting). \
     Reject it at the catch-all: %s.handle (m : Message.t) = match m with ... \
     | _ -> Error \"unexpected\" (or | s -> Error (`Unexpected s))."
    (String.capitalize_ascii module_)
    (String.capitalize_ascii module_)

let rule =
  Rule.v ~code:"E951" ~title:"Reject unexpected messages"
    ~category:Rule.Project_structure
    ~hint:
      "A catch-all arm over the protocol message type must reject the message \
       (| _ -> Error _, or | s -> Error (`Unexpected s)), not silently accept \
       it by returning a normal value (Ok / a state / unit). A silent accept \
       is the FREAK/SKIP-class bug: the machine keeps going on a message it \
       should have rejected. See E946-E950 and E952 for the rest of the \
       protocol shape."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
