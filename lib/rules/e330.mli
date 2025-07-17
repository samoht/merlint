(** E330: Redundant Module Name

    This rule detects when function or type names include the module name, which
    is redundant (e.g., My_module.my_module_do_thing). *)

val rule : Rule.t
(** The E330 rule definition *)
