(** E217: f (Fmt.str ...) — prefer the matching Fmt helper *)

type payload = { suggested : string }

(** Outer applications already covered by a more specific rule with a dedicated
    [Fmt.X] helper. Skip them here so the user sees only the specialized hint,
    not also the generic [Fmt.kstr] one. *)
let handled_by_specialized_rule fn =
  Ast.lident_last_eq "failwith" fn
  || Ast.lident_last_eq "invalid_arg" fn
  ||
  let path = Longident.flatten fn in
  path = [ "Alcotest"; "fail" ] || path = [ "fail" ]

(** [|>] threads a value left-to-right: [x |> Fmt.str "..." args] is a natural
    pipeline, and the [Fmt.kstr g "..." args x] rewrite would reverse the data
    flow. Skip pipe applications. ([@@] is precedence sugar for direct
    application and stays flagged.) *)
let is_pipe_operator fn = Longident.flatten fn = [ "|>" ]

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
let is_operator fn =
  match List.rev (Longident.flatten fn) with
  | last :: _ -> is_operator_name last
  | [] -> false

(** Helper that matches the outer's purpose: [Buffer.add_string] writes into a
    buffer, so the right rewrite uses [Fmt.bprintf]; [print_endline] writes to
    [stdout] with a newline, so [Fmt.pr "...@."]; etc. Everything else falls
    back to [Fmt.kstr], which threads the formatted string through any
    continuation. *)
let suggestion_for_apply fn =
  match Longident.flatten fn with
  | [ "Buffer"; "add_string" ] ->
      "Fmt.pf (Fmt.with_buffer buf) \"...\" (hoist the formatter outside hot \
       loops)"
  | [ "print_endline" ] -> "Fmt.pr \"...@.\""
  | [ "print_string" ] -> "Fmt.pr \"...\""
  | [ "prerr_endline" ] -> "Fmt.epr \"...@.\""
  | [ "prerr_string" ] -> "Fmt.epr \"...\""
  | path -> Fmt.str "Fmt.kstr %s \"...\"" (String.concat "." path)

let suggestion_for_construct lid =
  match List.rev (Longident.flatten lid) with
  | last :: _ -> Fmt.str "Fmt.kstr (fun s -> %s s) \"...\"" last
  | [] -> "Fmt.kstr (fun s -> _ s) \"...\""

let last_positional_arg args =
  let positional = List.filter (fun (lbl, _) -> lbl = Asttypes.Nolabel) args in
  match List.rev positional with (_, last) :: _ -> Some last | [] -> None

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let content = Context.content ctx in
  match Ast.parse_structure ~filename content with
  | None -> []
  | Some structure ->
      let issues = ref [] in
      let is_fmt_str = Ast.is_apply_of [ "Fmt"; "str" ] in
      Ast.iter_expressions structure (fun expr ->
          let flag suggested =
            issues :=
              Issue.v
                ~loc:(Ast.merlint_of_loc ~filename expr.pexp_loc)
                { suggested }
              :: !issues
          in
          match expr.pexp_desc with
          | Pexp_apply ({ pexp_desc = Pexp_ident { txt = fn; _ }; _ }, args)
            when (not (handled_by_specialized_rule fn))
                 && (not (is_pipe_operator fn))
                 && not (is_operator fn) -> (
              match last_positional_arg args with
              | Some arg when is_fmt_str arg -> flag (suggestion_for_apply fn)
              | _ -> ())
          | Pexp_construct ({ txt = lid; _ }, Some arg) when is_fmt_str arg ->
              flag (suggestion_for_construct lid)
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
      \  - [Error (Fmt.str ...)] -> [Fmt.kstr (fun e -> Error e) \"...\"], or \
       a one-shot [error_msgf] helper in the package;\n\
      \  - any other [<f> (Fmt.str ...)] -> [Fmt.kstr <f> \"...\"].\n\
       Specialised cases for [failwith], [invalid_arg], [Alcotest.fail], and \
       bare [fail] are handled by E215, E216, and E616 respectively."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let parse s =
  if s = "" then Error (Fmt.str "empty input")
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
