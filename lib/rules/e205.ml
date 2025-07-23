(** E205: Consider Using Fmt Module *)

type payload = { module_used : string }

(** Check if this is a printf-like function *)
let is_printf_function base =
  String.ends_with ~suffix:"printf" base
  || String.ends_with ~suffix:"sprintf" base
  || String.ends_with ~suffix:"asprintf" base

let check (ctx : Context.file) =
  let issues = ref [] in

  (* Check identifiers for Printf/Format module usage *)
  Dump.iter_identifiers_with_location (Context.dump ctx) (fun id loc ->
      let name = id.name in
      let prefix = name.prefix in
      let base = name.base in

      (* Check for Printf/Format module usage *)
      match prefix with
      | [ "Stdlib"; "Printf" ] ->
          issues := Issue.v ~loc { module_used = "Printf" } :: !issues
      | [ "Stdlib"; "Format" ] when is_printf_function base ->
          issues := Issue.v ~loc { module_used = "Format" } :: !issues
      | _ -> ());

  !issues

let pp ppf { module_used } =
  Fmt.pf ppf "Consider using Fmt module instead of %s for better formatting"
    module_used

let rule =
  Rule.v ~code:"E205" ~title:"Consider Using Fmt Module"
    ~category:Style_modernization
    ~hint:
      "The Fmt module provides a more modern and composable approach to \
       formatting. It offers better type safety and cleaner APIs compared to \
       Printf/Format modules."
    ~examples:
      [ Example.bad Examples.E205.bad_ml; Example.good Examples.E205.good_ml ]
    ~pp (File check)
