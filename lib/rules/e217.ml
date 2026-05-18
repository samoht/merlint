(** E217: f (Fmt.str ...) — prefer the matching Fmt helper *)

module T = Ocaml_typing.Typedtree

type payload = { suggested : string }

(** Outer applications already covered by a more specific rule with a dedicated
    [Fmt.X] helper. Skip them here so the user sees only the specialized hint,
    not also the generic [Fmt.kstr] one. *)
let handled_by_specialized_rule path =
  match List.rev path with
  | "failwith" :: _ | "invalid_arg" :: _ -> true
  | _ -> path = [ "Alcotest"; "fail" ]

(** [|>] threads a value left-to-right: [x |> Fmt.str "..." args] is a natural
    pipeline, and the [Fmt.kstr g "..." args x] rewrite would reverse the data
    flow. Skip pipe applications. ([@@] is precedence sugar for direct
    application and stays flagged.) *)
let is_pipe_operator path = path = [ "|>" ]

(** [true] when [name] is an OCaml operator identifier — same first-character
    classification the lexer / [Pprintast.is_infix] use, plus the named infix
    operators ([mod], [land], [lor], [lxor], [lsl], [lsr], [asr], [or]). *)
let is_operator_name name =
  match name with
  | "" -> false
  | "mod" | "land" | "lor" | "lxor" | "lsl" | "lsr" | "asr" | "or" | "&" -> true
  | _ -> (
      match name.[0] with
      | '!' | '$' | '%' | '&' | '*' | '+' | '-' | '.' | '/' | ':' | '<' | '='
      | '>' | '?' | '@' | '^' | '|' | '~' ->
          true
      | _ -> false)

(** Infix operators take their formatted string as the second positional
    argument, not as a continuation. Rewriting [cmd % Fmt.str "..."] as
    [Fmt.kstr (%) "..."] does not typecheck because [(%)] expects its first
    argument before the string, while [Fmt.kstr] only feeds the string. Skip
    operator applications — the user can still hoist [Fmt.str] into a [let] if
    they want to avoid the allocation.

    The OCaml AST has no explicit "infix" flag; operator-ness is inferred from
    the identifier's character class. Qualified forms ([Bos.Cmd.( % )]) flatten
    to a path whose last segment is the operator, so look at the last component.
*)
let is_operator path =
  match List.rev path with last :: _ -> is_operator_name last | [] -> false

(** Helper that matches the outer's purpose: [Buffer.add_string] writes into a
    buffer, so the right rewrite uses [Fmt.bprintf]; [print_endline] writes to
    [stdout] with a newline, so [Fmt.pr "...@."]; etc. Everything else falls
    back to [Fmt.kstr], which threads the formatted string through any
    continuation. *)
let suggestion_for_apply path =
  let path = match path with "Stdlib" :: rest -> rest | rest -> rest in
  match path with
  | [ "Buffer"; "add_string" ] ->
      "Fmt.pf (Fmt.with_buffer buf) \"...\" (hoist the formatter outside hot \
       loops)"
  | [ "print_endline" ] -> "Fmt.pr \"...@.\""
  | [ "print_string" ] -> "Fmt.pr \"...\""
  | [ "prerr_endline" ] -> "Fmt.epr \"...@.\""
  | [ "prerr_string" ] -> "Fmt.epr \"...\""
  | path -> Fmt.str "Fmt.kstr %s \"...\"" (String.concat "." path)

let suggestion_for_construct path =
  match List.rev path with
  | last :: _ -> Fmt.str "Fmt.kstr (fun s -> %s s) \"...\"" last
  | [] -> "Fmt.kstr (fun s -> _ s) \"...\""

let is_unary_fmt_str_arg args =
  match Query.Expr.positional_args args with
  | [ arg ] -> Query.Expr.calls arg [ "Fmt"; "str" ]
  | _ -> false

let is_explicit_output_helper path =
  let path = match path with "Stdlib" :: rest -> rest | rest -> rest in
  match path with
  | [ "Buffer"; "add_string" ]
  | [ "print_endline" ]
  | [ "print_string" ]
  | [ "prerr_endline" ]
  | [ "prerr_string" ] ->
      true
  | _ -> false

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let issues = ref [] in
  Query.iter_expressions (Context.view ctx) (fun expr ->
      let flag suggested =
        issues :=
          Issue.v ~loc:(Loc.of_typed ~filename expr.T.exp_loc) { suggested }
          :: !issues
      in
      match expr.exp_desc with
      | Texp_apply (fn, args) -> (
          match Query.Expr.callee_parts fn with
          | Some path
            when (not (handled_by_specialized_rule path))
                 && (not (is_pipe_operator path))
                 && not (is_operator path) -> (
              let rewriteable =
                if is_explicit_output_helper path then
                  match Query.Expr.last_positional_arg args with
                  | Some arg -> Query.Expr.calls arg [ "Fmt"; "str" ]
                  | None -> false
                else is_unary_fmt_str_arg args
              in
              if rewriteable then flag (suggestion_for_apply path))
          | _ -> ())
      | Texp_construct (lid, _, [ arg ])
        when Query.Expr.calls arg [ "Fmt"; "str" ] ->
          flag (suggestion_for_construct (Query.Longident.parts lid.txt))
      | _ -> ());
  List.rev !issues

let pp ppf { suggested } =
  Fmt.pf ppf "Wrap with [%s] instead of [... (Fmt.str ...)]" suggested

let rule =
  Rule.v ~code:"E217" ~title:"Prefer the matching Fmt helper over (Fmt.str ...)"
    ~category:Style_modernization
    ~hint:
      "Most calls of the shape [<f> (Fmt.str ...)] have a direct [Fmt.X] \
       equivalent that avoids the intermediate [Fmt.str] string allocation and \
       reads better:\n\
      \  - [Buffer.add_string buf (Fmt.str ...)] -> [Fmt.pf (Fmt.with_buffer \
       buf) \"...\"]\n\
      \    (hoist the formatter outside any hot loop to avoid re-allocating);\n\
      \  - [print_endline (Fmt.str ...)] -> [Fmt.pr \"...@.\"];\n\
      \  - [print_string (Fmt.str ...)] -> [Fmt.pr \"...\"];\n\
      \  - [prerr_endline (Fmt.str ...)] -> [Fmt.epr \"...@.\"];\n\
      \  - [prerr_string (Fmt.str ...)] -> [Fmt.epr \"...\"];\n\
      \  - [Error (... formatted with Fmt.str ...)] -> [Fmt.kstr (fun e -> \
       Error e) \"...\"], or a one-shot [error_msgf] helper in the package;\n\
      \  - any other [<f> (Fmt.str ...)] -> [Fmt.kstr <f> \"...\"].\n\
       Specialised cases for [failwith], [invalid_arg], [Alcotest.fail], and \
       bare [fail] are handled by E215, E216, and E616 respectively."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let parse s =
  if s = "" then Fmt.kstr (fun e -> Error e) "empty input"
  else Ok s

let log_event buf ev =
  Buffer.add_string buf (Fmt.str "[%s] %s\n" ev.kind ev.message)

let trace n = print_endline (Fmt.str "n=%d" n)|};
        };
        {
          is_good = true;
          code =
            {|let parse s =
  if s = "" then Fmt.kstr (fun e -> Error e) "empty input"
  else Ok s

let log_event buf ev =
  Fmt.bprintf buf "[%s] %s\n" ev.kind ev.message

let trace n = Fmt.pr "n=%d@." n|};
        };
      ]
    ~pp (File check)
