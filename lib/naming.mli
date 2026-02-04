(** Naming convention utilities. *)

val to_capitalized_snake_case : string -> string
(** [to_capitalized_snake_case name] converts PascalCase to Snake_case (for
    modules/variants/constructors).

    Simple consistent rules: 1. All uppercase names stay as is (XML, III, ABC)
    2. Names with underscores stay as is (Already_correct) 3. Otherwise, split
    at word boundaries and join with underscores:
    - First 2 uppercase letters stay together if followed by lowercase (OCaml ->
      OCaml)
    - Trailing uppercase letters stay together (PartIII -> Part_III, ParseHTML
      -> Parse_HTML)
    - Other uppercase boundaries split normally (XMLParser -> XML_parser,
      IOError -> IO_error)

    The first word always keeps its original capitalization. Subsequent
    all-uppercase words (acronyms) keep their capitalization. Other words are
    lowercased. *)

val to_lowercase_snake_case : string -> string
(** [to_lowercase_snake_case name] converts any case to lowercase_snake_case
    (for values/types/fields). Uses the same splitting rules as
    to_capitalized_snake_case, then lowercases everything.

    Examples:
    - getUserName -> get_user_name
    - XMLParser -> xml_parser
    - IOError -> io_error
    - OCamlCompiler -> ocaml_compiler. *)

val is_pascal_case : string -> bool
(** [is_pascal_case name] checks if name follows PascalCase convention. *)
