(** E218: extract [Fmt.kstr (fun _ -> Error/raise ...) ...] into helpers *)

type wrap_kind = Err | Fail
type variant = Inline | Rename
type payload = { variant : variant; suggested : string }

module T = Ocaml_typing.Typedtree

let is_error_construct lid =
  match List.rev (Query.Longident.parts lid) with
  | "Error" :: _ -> true
  | _ -> false

let is_raise_path path =
  match List.rev path with
  | ("raise" | "raise_notrace") :: _ -> true
  | _ -> false

(** [Pexp_function (_, _, Pfunction_body body)] whose [body] is [Error ...]
    (returns [Some (Err, payload)]) or [raise ...] (returns
    [Some (Fail, exn_expr)]). Otherwise [None]. *)
let wraps_error_or_raise (expr : T.expression) =
  let body =
    match expr.exp_desc with
    | Texp_function (_, Tfunction_body body) -> Some body
    | _ -> None
  in
  match body with
  | Some { exp_desc = Texp_construct (lid, _, [ payload ]); _ }
    when is_error_construct lid.txt ->
      Some (Err, payload)
  | Some { exp_desc = Texp_apply (fn, args); _ } -> (
      match (Query.Expr.callee_parts fn, Query.Expr.positional_args args) with
      | Some path, [ exn ] when is_raise_path path -> Some (Fail, exn)
      | _ -> None)
  | _ -> None

(** Lowercased constructor or function name, used purely as a hint stem in the
    suggested helper name. The user picks the final domain-appropriate name when
    they actually extract. *)
let stem_of_payload (payload : T.expression) =
  match payload.exp_desc with
  | Texp_apply (fn, _) ->
      Option.bind (Query.Expr.callee_parts fn) (fun path ->
          match List.rev path with
          | last :: _ -> Some (String.lowercase_ascii last)
          | [] -> None)
  | Texp_construct (lid, _, _) -> (
      match List.rev (Query.Longident.parts lid.txt) with
      | last :: _ -> Some (String.lowercase_ascii last)
      | [] -> None)
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

let kstr_wrap_fn (expr : T.expression) =
  let rec flatten_apply expr =
    match expr.T.exp_desc with
    | Texp_apply (fn, args) ->
        let head, previous_args = flatten_apply fn in
        (head, previous_args @ Query.Expr.positional_args args)
    | _ -> (expr, [])
  in
  let head, args = flatten_apply expr in
  if Query.Expr.callee_ends_with head [ "Fmt"; "kstr" ] then Some args else None

(** Match [Fmt.kstr (fun s -> Error/raise _) ...] regardless of whether the
    format is a literal or a threaded [fmt] parameter. Returns the wrap kind
    plus the [Error]/[raise] payload. *)
let flagged_kstr_any (expr : T.expression) =
  match kstr_wrap_fn expr with
  | Some (wrap_fn :: _) -> wraps_error_or_raise wrap_fn
  | _ -> None

(** Inline call site: [Fmt.kstr (fun s -> Error/raise _) ...]. Top-level helpers
    are skipped by location before this predicate is consulted. *)
let flagged_kstr_inline (expr : T.expression) =
  match kstr_wrap_fn expr with
  | Some (wrap_fn :: _fmt_arg :: _) -> wraps_error_or_raise wrap_fn
  | _ -> None

(** Descend through curried-function layers to the body of a let binding.
    [let f x y = body] -> [body]; [let f = body] -> [body]. *)
let body_of_function = Query.Expr.body

(** Extract the name of a pattern binding, if it's a simple [Ppat_var]. *)
let name_of_pattern = Query.Pattern.var_name

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
let mismatch_suggestion name kind =
  let prefix = match kind with Err -> "err" | Fail -> "fail" in
  Fmt.str
    "rename '%s' to '%s_<x>' (helpers that wrap [Error]/[raise] should start \
     with [err_]/[fail_])"
    name prefix

type state = {
  filename : string;
  helper_locs : Ocaml_parsing.Location.t list ref;
  issues : payload Issue.t list ref;
}

let visit_value_binding state (vb : T.value_binding) =
  let body = body_of_function vb.vb_expr in
  match flagged_kstr_any body with
  | None -> ()
  | Some (kind, _payload) -> (
      state.helper_locs := body.exp_loc :: !(state.helper_locs);
      match name_of_pattern vb.vb_pat with
      | Some name when not (name_matches_kind name kind) ->
          let suggested = mismatch_suggestion name kind in
          state.issues :=
            Issue.v
              ~loc:(Loc.of_typed ~filename:state.filename body.exp_loc)
              { variant = Rename; suggested }
            :: !(state.issues)
      | _ -> ())

let visit_expr state (expr : T.expression) =
  let is_helper = List.mem expr.T.exp_loc !(state.helper_locs) in
  if not is_helper then
    match flagged_kstr_inline expr with
    | None -> ()
    | Some (kind, payload) ->
        let suggested = suggestion kind (stem_of_payload payload) in
        state.issues :=
          Issue.v
            ~loc:(Loc.of_typed ~filename:state.filename expr.exp_loc)
            { variant = Inline; suggested }
          :: !(state.issues)

let init ctx =
  { filename = Context.filename ctx; helper_locs = ref []; issues = ref [] }

let finish _ state = List.rev !(state.issues)

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
    ~examples ~pp
    (Rule.pass ~init ~value_binding:visit_value_binding ~expr:visit_expr ~finish
       ())
