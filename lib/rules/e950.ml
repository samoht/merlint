(** E950: Total protocol transitions.

    A protocol's state machine returns errors as values, never as exceptions:
    [handle] yields a [result], so a malformed peer message is data the caller
    dispatches on, not an exception that unwinds the stack. nqsb-tls (USENIX
    2015) makes this total-transition discipline the core of its auditable state
    machine -- the FREAK/SKIP-class bugs came from stacks that took an
    exceptional path on unexpected input.

    This rule flags, in a state-machine module (see {!Protocol_modules}), a call
    to [raise], [raise_notrace], [failwith], or [invalid_arg], and any [assert]
    (including [assert false]): each unwinds the stack on a value the transition
    should fold into its result. Reject bad input by returning an [Error], and
    make a genuinely unreachable case unreachable in the *type* (so no
    [assert false] is needed -- the "Established is its own type" guidance)
    rather than asserting at runtime. *)

module FV = File_view

type payload = { module_ : string; how : string }

let raising = [ "raise"; "raise_notrace"; "failwith"; "invalid_arg" ]

let check (ctx : Context.project) (m : Protocol_modules.machine_module) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        let issues = ref [] in
        let add ~loc how =
          issues := Issue.v ~loc { module_ = m.module_name; how } :: !issues
        in
        FV.iter_applications view (fun call ->
            let base = FV.Name.base (FV.Call.callee call) in
            if List.mem base raising then add ~loc:(FV.Call.loc call) base);
        FV.iter_asserts view (fun loc -> add ~loc "assert");
        List.rev !issues

let enumerate ctx = Protocol_modules.protocol_machine_modules ctx

let pp ppf { module_; how } =
  Fmt.pf ppf
    "%s is not total: it raises via %s. A protocol transition rejects bad \
     input by returning an Error value; make a genuinely unreachable case \
     unreachable in the type rather than asserting."
    (String.capitalize_ascii module_)
    how

let rule =
  Rule.v ~code:"E950" ~title:"Total protocol transitions"
    ~category:Rule.Project_structure
    ~hint:
      "A protocol's state machine is total: it returns errors as values, never \
       raises. In a state-machine module, reject bad input with an Error \
       rather than raise / failwith / invalid_arg. See E946-E949 for the rest \
       of the protocol shape."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
