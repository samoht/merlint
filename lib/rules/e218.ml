(** E218: extract [Fmt.kstr (fun _ -> Error/raise ...) ...] into helpers *)

type wrap_kind = Err | Fail
type variant = Inline | Rename
type payload = { variant : variant; suggested : string }

open Ocaml_parsing

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

let is_literal_format (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_constant { pconst_desc = Pconst_string _; _ } -> true
  | _ -> false

let kstr_wrap_fn (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_apply (_, args) when Ast.is_apply_of [ "Fmt"; "kstr" ] expr ->
      let positional =
        List.filter_map
          (fun (lbl, e) -> if lbl = Asttypes.Nolabel then Some e else None)
          args
      in
      Some positional
  | _ -> None

(** Match [Fmt.kstr (fun s -> Error/raise _) ...] regardless of whether the
    format is a literal or a threaded [fmt] parameter. Returns the wrap kind
    plus the [Error]/[raise] payload. *)
let flagged_kstr_any (expr : Parsetree.expression) =
  match kstr_wrap_fn expr with
  | Some (wrap_fn :: _) -> wraps_error_or_raise wrap_fn
  | _ -> None

(** Inline call site: [Fmt.kstr (fun s -> Error/raise _) "literal" ...].
    Distinguished from a helper definition (which threads a [fmt] parameter) by
    the literal format. *)
let flagged_kstr_inline (expr : Parsetree.expression) =
  match kstr_wrap_fn expr with
  | Some (wrap_fn :: fmt_arg :: _) when is_literal_format fmt_arg ->
      wraps_error_or_raise wrap_fn
  | _ -> None

(** Descend through curried-function layers to the body of a let binding.
    [let f x y = body] -> [body]; [let f = body] -> [body]. *)
let rec body_of_function (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_function (_, _, Pfunction_body inner) -> body_of_function inner
  | _ -> expr

(** Extract the name of a pattern binding, if it's a simple [Ppat_var]. *)
let name_of_pattern (pat : Parsetree.pattern) =
  match pat.ppat_desc with Ppat_var { txt; _ } -> Some txt | _ -> None

(** Naming convention: an [Err]-wrapping helper should be [err] or [err_*]; a
    [Fail]-wrapping helper should be [fail] or [fail_*]. *)
let name_matches_kind name kind =
  let prefix = match kind with Err -> "err" | Fail -> "fail" in
  name = prefix || String.starts_with ~prefix:(prefix ^ "_") name

(** Walk top-level [let] bindings (and module structures); for each binding
    whose body is a flagged [Fmt.kstr ...] expression, return
    [(body_loc, binding_name, kind, payload)]. The body location is so the
    inline-call iterator can skip it; the name is so we can flag mis-named
    helpers. *)
let collect_helpers structure =
  let helpers = ref [] in
  let collect_binding (vb : Parsetree.value_binding) =
    let body = body_of_function vb.pvb_expr in
    match flagged_kstr_any body with
    | None -> ()
    | Some (kind, payload) ->
        let name = name_of_pattern vb.pvb_pat in
        helpers := (body.pexp_loc, name, kind, payload) :: !helpers
  in
  let rec walk_str_item (item : Parsetree.structure_item) =
    match item.pstr_desc with
    | Pstr_value (_, bindings) -> List.iter collect_binding bindings
    | Pstr_module mb -> walk_module_expr mb.pmb_expr
    | Pstr_recmodule mbs ->
        List.iter
          (fun (mb : Parsetree.module_binding) -> walk_module_expr mb.pmb_expr)
          mbs
    | _ -> ()
  and walk_module_expr (me : Parsetree.module_expr) =
    match me.pmod_desc with
    | Pmod_structure s -> List.iter walk_str_item s
    | _ -> ()
  in
  List.iter walk_str_item structure;
  !helpers

let mismatch_suggestion name kind =
  let prefix = match kind with Err -> "err" | Fail -> "fail" in
  Fmt.str
    "rename '%s' to '%s_<x>' (helpers that wrap [Error]/[raise] should start \
     with [err_]/[fail_])"
    name prefix

let check (ctx : Context.file) =
  let filename = ctx.filename in
  match File_view.parsetree (Context.view ctx) with
  | None -> []
  | Some structure ->
      let helpers = collect_helpers structure in
      let helper_locs = List.map (fun (loc, _, _, _) -> loc) helpers in
      let issues = ref [] in
      List.iter
        (fun (loc, name, kind, _payload) ->
          match name with
          | Some n when not (name_matches_kind n kind) ->
              let suggested = mismatch_suggestion n kind in
              issues :=
                Issue.v
                  ~loc:(Ast.merlint_of_loc ~filename loc)
                  { variant = Rename; suggested }
                :: !issues
          | _ -> ())
        helpers;
      Ast.iter_expressions structure (fun expr ->
          let is_helper = List.mem expr.Parsetree.pexp_loc helper_locs in
          if is_helper then ()
          else
            match flagged_kstr_inline expr with
            | None -> ()
            | Some (kind, payload) ->
                let suggested = suggestion kind (stem_of_payload payload) in
                issues :=
                  Issue.v
                    ~loc:(Ast.merlint_of_loc ~filename expr.pexp_loc)
                    { variant = Inline; suggested }
                  :: !issues);
      List.rev !issues

let pp ppf { variant; suggested } =
  match variant with
  | Inline ->
      Fmt.pf ppf
        "Inline [Fmt.kstr (fun _ -> Error/raise _) ...] should be a \
         top-of-file helper: %s"
        suggested
  | Rename -> Fmt.pf ppf "Helper name doesn't match its body: %s" suggested

let bad_example =
  {|exception Parse_error of string

let parse_int s =
  match int_of_string_opt s with
  | Some n -> n
  | None -> Fmt.kstr (fun s -> raise (Parse_error s)) "not an int: %S" s

let parse s =
  if s = "" then Fmt.kstr (fun s -> Error s) "empty input"
  else if String.length s > 100 then
    Fmt.kstr (fun s -> Error s) "input too long: %d" (String.length s)
  else Ok s|}

let good_example =
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
  else Ok s|}

let examples = [ Example.bad bad_example; Example.good good_example ]

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
    ~examples ~pp (File check)
