(** merlint's exit status: the bits a run answers with, the values a caller
    could not read as merlint's answer, and the manual entry that publishes
    both. One module owns them so the number a run returns and the number its
    manual documents cannot disagree. *)

val findings : int
(** [findings] is bit 0: the code merlint read has issues to fix. *)

val incomplete : int
(** [incomplete] is bit 1: merlint could not look at part of what it was pointed
    at. *)

val refused : int
(** [refused] is bit 2: merlint computed no verdict at all, so the counts beside
    it are zero because there was nothing to count. *)

val bits : int list
(** [bits] is every bit the status is spelled from. {!all} and the
    reserved-value test derive from it, so a bit added here is a bit they cover.
*)

val all : int list
(** [all] is every status this mask can spell: each subset of {!bits} folded
    with [lor]. It is deliberately a superset of what a run emits today --
    {!refused} stands alone -- because a mask that can spell a reserved value is
    one refactor away from returning one. *)

val reserved_reason : int -> string option
(** [reserved_reason status] is [Some why] when a caller reading [status] could
    not tell merlint's answer from something else's, and [None] otherwise. *)

val of_run : findings:int -> unchecked:int -> skipped:int -> failed:int -> int
(** [of_run ~findings ~unchecked ~skipped ~failed] is the status of a run that
    reported [findings] issues over a tree in which [unchecked] files, [skipped]
    paths and [failed] checks went unread. It never returns {!refused}: a run
    that got far enough to count these things is a run that looked. *)

val exits : Cmdliner.Cmd.Exit.info list
(** [exits] is the manual's exit-status section, covering every value merlint
    returns. *)
