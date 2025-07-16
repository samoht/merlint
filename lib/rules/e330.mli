(** E330: Redundant Module Name

    This rule detects when function or type names include the module name, which
    is redundant (e.g., My_module.my_module_do_thing). *)

val check : Context.file -> Issue.t list
(** [check ~filename ~outline] analyzes the outline to find items with redundant
    module prefixes in their names. Returns a list of issues for items that
    violate the rule. *)
