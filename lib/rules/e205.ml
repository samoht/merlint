(** E205: Consider Using Fmt Module *)

type payload = { module_used : string }

(** Check if this is a printf-like function *)
let is_printf_function base =
  String.ends_with ~suffix:"printf" base
  || String.ends_with ~suffix:"sprintf" base
  || String.ends_with ~suffix:"asprintf" base

(* Resolved typedtree paths only — a user's local [Printf] / [Format]
   should not trip this rule. Skip the file when only parsetree is
   available; the engine surfaces the missing-resolution count. *)
let check (ctx : Context.file) =
  match File_view.resolved_identifiers (Context.view ctx) with
  | None -> []
  | Some identifiers ->
      let issues = ref [] in
      List.iter
        (fun ident ->
          match File_view.Reference.loc ident with
          | None -> ()
          | Some loc -> (
              let prefix = File_view.Reference.prefix ident in
              let base = File_view.Reference.base ident in
              match prefix with
              | [ "Stdlib"; "Printf" ] ->
                  issues := Issue.v ~loc { module_used = "Printf" } :: !issues
              | [ "Stdlib"; "Format" ] when is_printf_function base ->
                  issues := Issue.v ~loc { module_used = "Format" } :: !issues
              | _ -> ()))
        identifiers;
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
