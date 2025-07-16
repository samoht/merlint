(** E105: Catch-All Exception Handlers

    This rule detects catch-all exception handlers (try...with _ ->) which can
    hide important errors and make debugging difficult. *)

val check : Context.file -> Issue.t list
(** [check file_path file_content] detects catch-all exception handlers
    (try...with _ ->) in file content. Returns a list of issues for each
    catch-all handler found. *)
