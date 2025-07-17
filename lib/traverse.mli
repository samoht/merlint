(** Common traversal helpers for AST analysis *)

(** {2 AST element iteration and filtering} *)

val filter_map_elements : Ast.elt list -> (Ast.elt -> 'a option) -> 'a list
(** [filter_map_elements elements f] applies [f] to each element and collects
    the results *)

val iter_identifiers_with_location :
  Ast.t -> (Ast.elt -> Location.t -> unit) -> unit
(** [iter_identifiers_with_location ast_data f] applies [f] to each identifier
    that has a location *)

(** {2 Location extraction helpers} *)

val extract_location : Ast.elt -> Location.t option
(** [extract_location elt] extracts location from element *)

val extract_outline_location : string -> Outline.item -> Location.t option
(** [extract_outline_location filename item] extracts location from outline item
*)

(** {2 Name conversion helpers} *)

val to_snake_case : string -> string
(** [to_snake_case name] converts PascalCase to snake_case *)

val to_pascal_case : string -> string
(** [to_pascal_case name] converts snake_case to PascalCase *)

val is_pascal_case : string -> bool
(** [is_pascal_case name] checks if name follows PascalCase convention *)

(** {2 AST name matching} *)

(** {2 File processing helpers} *)

val process_ocaml_files :
  Context.project -> (string -> string -> 'a list) -> 'a list
(** [process_ocaml_files ctx f] processes all OCaml files in project with
    function [f] *)

val process_lines_with_location :
  string -> string -> (int -> string -> Location.t -> 'a option) -> 'a list
(** [process_lines_with_location filename content f] processes lines with
    location information *)

(** {2 Type signature analysis} *)

val is_function_type : string -> bool
(** [is_function_type signature] checks if signature represents a function type
*)

val extract_return_type : string -> string
(** [extract_return_type signature] extracts return type from function signature
*)

val count_parameters : string -> string -> int
(** [count_parameters signature param_type] counts occurrences of param_type in
    signature *)

(** {2 Browse data helpers} *)

val filter_functions : Browse.value_binding list -> Browse.value_binding list
(** [filter_functions bindings] filters only function bindings *)

(** {2 Common validation patterns} *)

val check_module_usage :
  Ast.elt list -> string -> (loc:Location.t -> 'a) -> 'a list
(** [check_module_usage identifiers module_name issue_constructor] checks for
    specific module usage *)

val check_function_usage :
  Ast.elt list -> string -> string -> (loc:Location.t -> 'a) -> 'a list
(** [check_function_usage identifiers module_name function_name
     issue_constructor] checks for specific function usage *)

val check_elements :
  Ast.elt list ->
  (string -> 'a option) ->
  (string -> Location.t -> 'a -> 'b) ->
  'b list
(** [check_elements elements check_fn create_issue_fn] generic element checking
    pattern *)

(** {2 Helper for extracting specific AST element types} *)
