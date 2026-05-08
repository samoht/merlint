(** E218: extract [Fmt.kstr (fun _ -> Error/raise ...) ...] into helpers *)

type wrap_kind = Err | Fail
type payload = { suggested : string }

let is_error_construct (lid : Longident.t) =
  match List.rev (Longident.flatten lid) with
  | "Error" :: _ -> true
  | _ -> false

let is_raise_ident (lid : Longident.t) =
  match List.rev (Longident.flatten lid) with
  | ("raise" | "raise_notrace") :: _ -> true
  | _ -> false

(** [Pexp_function (_, _, Pfunction_body body)] whose [body] is [Error ...]
    (returns [Some (Err, payload)]) or [raise ...] (returns
    [Some (Fail, exn_expr)]). Otherwise [None]. *)
let wraps_error_or_raise (expr : Parsetree.expression) =
  let body =
    match expr.pexp_desc with
    | Pexp_function (_, _, Pfunction_body body) -> Some body
    | _ -> None
  in
  match body with
  | Some { pexp_desc = Pexp_construct ({ txt; _ }, Some payload); _ }
    when is_error_construct txt ->
      Some (Err, payload)
  | Some
      {
        pexp_desc =
          Pexp_apply
            ( { pexp_desc = Pexp_ident { txt; _ }; _ },
              [ (Asttypes.Nolabel, exn) ] );
        _;
      }
    when is_raise_ident txt ->
      Some (Fail, exn)
  | _ -> None

(** Lowercased constructor or function name, used purely as a hint stem in the
    suggested helper name. The user picks the final domain-appropriate name when
    they actually extract. *)
let stem_of_payload (payload : Parsetree.expression) =
  match payload.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _)
  | Pexp_construct ({ txt; _ }, _) ->
      let last = Longident.flatten txt |> List.rev |> List.hd in
      Some (String.lowercase_ascii last)
  | _ -> None

let helper_name kind stem =
  let prefix = match kind with Err -> "err" | Fail -> "fail" in
  match stem with Some s -> prefix ^ "_" ^ s | None -> prefix

let suggestion kind stem =
  let helper = helper_name kind stem in
  let body =
    match kind with
    | Err -> "Fmt.kstr (fun s -> Error (...)) fmt"
    | Fail -> "Fmt.kstr (fun s -> raise (...)) fmt"
  in
  Fmt.str "let %s fmt = %s    (call: %s \"...\")" helper body helper

(** A literal-string format argument signals an inline call site. Helper
    definitions thread a [fmt] parameter through, so the kstr's first positional
    argument after the function is a [Pexp_ident], not a string constant — those
    should not be flagged. *)
let is_literal_format (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_constant { pconst_desc = Pconst_string _; _ } -> true
  | _ -> false

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let content = Context.content ctx in
  match Ast.parse_structure ~filename content with
  | None -> []
  | Some structure ->
      let issues = ref [] in
      Ast.iter_expressions structure (fun expr ->
          match expr.pexp_desc with
          | Pexp_apply (_, args) when Ast.is_apply_of [ "Fmt"; "kstr" ] expr
            -> (
              let positional =
                List.filter_map
                  (fun (lbl, e) ->
                    if lbl = Asttypes.Nolabel then Some e else None)
                  args
              in
              match positional with
              | wrap_fn :: fmt_arg :: _ when is_literal_format fmt_arg -> (
                  match wraps_error_or_raise wrap_fn with
                  | None -> ()
                  | Some (kind, payload) ->
                      let suggested =
                        suggestion kind (stem_of_payload payload)
                      in
                      issues :=
                        Issue.v
                          ~loc:(Ast.loc_to_merlint ~filename expr.pexp_loc)
                          { suggested }
                        :: !issues)
              | _ -> ())
          | _ -> ());
      List.rev !issues

let pp ppf { suggested } =
  Fmt.pf ppf
    "Inline [Fmt.kstr (fun _ -> Error/raise _) ...] should be a top-of-file \
     helper: %s"
    suggested

let rule =
  Rule.v ~code:"E218"
    ~title:"Extract Fmt.kstr Error/raise wrappers into let err_/fail_ helpers"
    ~category:Style_modernization
    ~hint:
      "When the same [Fmt.kstr (fun s -> Error (Constructor s)) ...] or \
       [Fmt.kstr (fun s -> raise (Constructor s)) ...] lambda appears at \
       multiple call sites, extract a small helper at the top of the file:\n\n\
      \  let err_x  fmt = Fmt.kstr (fun s -> Error (Constructor s)) fmt\n\
      \  let fail_x fmt = Fmt.kstr (fun s -> raise (Constructor s)) fmt\n\n\
       and replace each call site with [err_x \"...\" args] / [fail_x \"...\" \
       args]. The lambda reads as noise at the call site; the helper reads as \
       the domain operation (\"emit a wire error\", \"raise a parse \
       failure\"). For a single one-off site the inline form is fine — the \
       helper is a deduplication tool. The rule only flags inline call sites \
       (kstr with a literal-string format) and skips helper definitions, which \
       thread a [fmt] parameter."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|exception Parse_error of string

let parse_int s =
  match int_of_string_opt s with
  | Some n -> n
  | None -> Fmt.kstr (fun s -> raise (Parse_error s)) "not an int: %S" s

let parse s =
  if s = "" then Fmt.kstr (fun s -> Error s) "empty input"
  else if String.length s > 100 then
    Fmt.kstr (fun s -> Error s) "input too long: %d" (String.length s)
  else Ok s|};
        };
        {
          is_good = true;
          code =
            {|exception Parse_error of string

let fail_parse fmt = Fmt.kstr (fun s -> raise (Parse_error s)) fmt
let err fmt = Fmt.kstr (fun s -> Error s) fmt

let parse_int s =
  match int_of_string_opt s with
  | Some n -> n
  | None -> fail_parse "not an int: %S" s

let parse s =
  if s = "" then err "empty input"
  else if String.length s > 100 then err "input too long: %d" (String.length s)
  else Ok s|};
        };
      ]
    ~pp (File check)
