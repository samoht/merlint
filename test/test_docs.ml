(** Tests for the Docs module *)

(* Helper to make style_issue testable for Alcotest *)
let style_issue : Merlint.Docs.style_issue Alcotest.testable =
  Alcotest.testable Merlint.Docs.pp_style_issue Merlint.Docs.equal_style_issue

(* The [name args] shape itself: brackets, the name inside them, the trailing
   period, and redundant phrasing. *)
let test_check_function_doc_format () =
  let open Merlint.Docs in
  (* Good function doc with [name args] format *)
  let issues =
    check_function_doc ~name:"foo" ~signature:"int -> int"
      ~doc:"[foo x] computes foo of x."
  in
  Alcotest.(check (list style_issue)) "good function doc" [] issues;

  (* Missing period *)
  let issues =
    check_function_doc ~name:"bar" ~signature:"int -> int"
      ~doc:"[bar x] computes bar of x"
  in
  Alcotest.(check (list style_issue)) "missing period" [ Missing_period ] issues;

  (* Redundant phrase - but no Bad_function_format since we're not using [name] format *)
  let issues =
    check_function_doc ~name:"baz" ~signature:"unit -> unit"
      ~doc:"This function computes baz."
  in
  Alcotest.(check (list style_issue))
    "redundant phrase only"
    [ Redundant_phrase "This function" ]
    issues;

  (* No bracket format is OK now - we only flag if [name] is used but wrong *)
  let issues =
    check_function_doc ~name:"qux" ~signature:"int -> int"
      ~doc:"Computes qux of x."
  in
  Alcotest.(check (list style_issue)) "no brackets is fine" [] issues;

  (* Brackets in prose are ignored by this style check. *)
  let issues =
    check_function_doc ~name:"qux" ~signature:"int -> int"
      ~doc:"Computes qux of [x]."
  in
  Alcotest.(check (list style_issue)) "bracket reference in prose" [] issues;

  (* Wrong name in [name] format *)
  let issues =
    check_function_doc ~name:"correct" ~signature:"int -> int"
      ~doc:"[wrong x] computes something."
  in
  Alcotest.(check (list style_issue))
    "wrong name in brackets" [ Bad_function_format ] issues

(* Whether the documented arguments match the signature's arity, including
   optional arguments and arrows that belong to an argument type rather than to
   the function itself. *)
let test_check_function_doc_arity () =
  let open Merlint.Docs in
  (* No arguments is OK: [fn] can simply name the function. *)
  let issues =
    check_function_doc ~name:"make"
      ~signature:"?foo:int -> ?bar:string -> unit -> t"
      ~doc:"[make] is a value with defaults."
  in
  Alcotest.(check (list style_issue)) "no args is fine" [] issues;

  (* Optional arguments may be omitted if all mandatory args are mentioned. *)
  let issues =
    check_function_doc ~name:"make"
      ~signature:"?foo:int -> ?bar:string -> unit -> t"
      ~doc:"[make ()] is a value with defaults."
  in
  Alcotest.(check (list style_issue)) "optional args may be omitted" [] issues;

  (* Mentioning args requires mentioning at least all mandatory args. *)
  let issues =
    check_function_doc ~name:"combine"
      ~signature:"?sep:string -> string -> string -> string"
      ~doc:"[combine x] combines strings."
  in
  Alcotest.(check (list style_issue))
    "too few mandatory args"
    [ Wrong_arg_count { min = 2; max = 3; found = 1 } ]
    issues;

  (* Too many arguments is suspicious and should be reported. *)
  let issues =
    check_function_doc ~name:"make"
      ~signature:"?foo:int -> ?bar:string -> unit -> t"
      ~doc:"[make a b c d] has too many documented arguments."
  in
  Alcotest.(check (list style_issue))
    "too many args"
    [ Wrong_arg_count { min = 1; max = 3; found = 4 } ]
    issues;

  (* Function with function-typed arguments - arrows inside parens should not count *)
  let issues =
    check_function_doc ~name:"field_codec"
      ~signature:
        "string -> ?constraint_:bool expr -> 'a typ -> get:('r -> 'a) -> \
         set:('a -> 'r -> 'r) -> ('a, 'r) field_codec"
      ~doc:
        "[field_codec name ?constraint_ typ ~get ~set] creates a field codec."
  in
  Alcotest.(check (list style_issue))
    "function-typed args (arrows inside parens)" [] issues;

  (* Function returning a tuple of functions - arrows in return tuple should not count *)
  let issues =
    check_function_doc ~name:"cycling"
      ~signature:
        "data:bytes -> n_items:int -> size:int -> (bytes -> int -> unit) -> \
         (unit -> unit) * (unit -> unit)"
      ~doc:"[cycling ~data ~n_items ~size read_fn] cycles through items."
  in
  Alcotest.(check (list style_issue))
    "function returning tuple of functions" [] issues

let test_check_value_doc () =
  let open Merlint.Docs in
  (* Good value doc with [name] format *)
  let issues =
    check_value_doc ~name:"version" ~doc:"[version] is the current version."
  in
  Alcotest.(check (list style_issue)) "good value doc" [] issues;

  (* No [name] format is OK now - we only flag if [name] is used but wrong *)
  let issues = check_value_doc ~name:"version" ~doc:"The current version." in
  Alcotest.(check (list style_issue)) "no bracket format is fine" [] issues;

  (* Brackets in prose are references, not the doc-prefix form. *)
  let issues =
    check_value_doc ~name:"version" ~doc:"The current [version] value."
  in
  Alcotest.(check (list style_issue))
    "value bracket reference in prose" [] issues;

  (* Bracketed literals are not value doc-prefixes. *)
  let issues =
    check_value_doc ~name:"authority" ~doc:"[:authority] pseudo-header."
  in
  Alcotest.(check (list style_issue)) "value bracket literal" [] issues;

  (* Missing period *)
  let issues =
    check_value_doc ~name:"count" ~doc:"[count] is the total count"
  in
  Alcotest.(check (list style_issue)) "missing period" [ Missing_period ] issues;

  (* Redundant phrase - but no Bad_value_format since we're not using [name] format *)
  let issues =
    check_value_doc ~name:"data" ~doc:"This value represents data."
  in
  Alcotest.(check (list style_issue))
    "redundant phrase only"
    [ Redundant_phrase "This value" ]
    issues;

  (* Wrong name in [name] format *)
  let issues = check_value_doc ~name:"correct" ~doc:"[wrong] is a bad name." in
  Alcotest.(check (list style_issue))
    "wrong name in brackets" [ Bad_value_format ] issues

(* A doc whose last element is an odoc block -- a code block, a verbatim
   block, or a list -- carries its punctuation inside the block, so the
   trailing '}' is not a missing period. An inline element closing the doc is
   still prose and still needs one. *)
let test_ends_with_block () =
  let open Merlint.Docs in
  let issues =
    check_function_doc ~name:"render" ~signature:"arg -> ret"
      ~doc:"[render t] renders [t]:\n{[\n  render t\n]}"
  in
  Alcotest.(check (list style_issue)) "code block" [] issues;

  let issues =
    check_function_doc ~name:"describe" ~signature:"arg -> ret"
      ~doc:
        "[describe t] is a one-word summary of [t]:\n\
         {ul\n\
        \ {- [\"empty\"] when [t] carries nothing.}\n\
        \ {- [\"full\"] otherwise.}}"
  in
  Alcotest.(check (list style_issue)) "list block" [] issues;

  let issues =
    check_value_doc ~name:"cases"
      ~doc:"[cases] are the outcomes.\n{ol\n {- Success.}\n {- Failure.}}"
  in
  Alcotest.(check (list style_issue)) "numbered list block" [] issues;

  let issues =
    check_value_doc ~name:"raw" ~doc:"[raw] is the wire form.\n{v\n  0102\nv}"
  in
  Alcotest.(check (list style_issue)) "verbatim block" [] issues;

  (* An inline element is prose: the period is still required. *)
  let issues =
    check_function_doc ~name:"render" ~signature:"arg -> ret"
      ~doc:"[render t] is the rendering of {b t}"
  in
  Alcotest.(check (list style_issue))
    "inline emphasis" [ Missing_period ] issues;

  let issues =
    check_value_doc ~name:"other" ~doc:"[other] is the peer of {!val-render}"
  in
  Alcotest.(check (list style_issue))
    "inline reference" [ Missing_period ] issues

let test_check_type_doc () =
  let open Merlint.Docs in
  (* Good type doc *)
  let issues = check_type_doc ~doc:"A user identifier." in
  Alcotest.(check (list style_issue)) "good type doc" [] issues;

  (* Missing period *)
  let issues = check_type_doc ~doc:"A user identifier" in
  Alcotest.(check (list style_issue)) "missing period" [ Missing_period ] issues;

  (* Redundant phrase *)
  let issues = check_type_doc ~doc:"This type represents a user." in
  Alcotest.(check (list style_issue))
    "redundant phrase"
    [ Redundant_phrase "This type" ]
    issues

let tests =
  let open Alcotest in
  [
    test_case "check_function_doc format" `Quick test_check_function_doc_format;
    Alcotest.test_case "check_function_doc arity" `Quick
      test_check_function_doc_arity;
    test_case "check_value_doc" `Quick test_check_value_doc;
    test_case "doc ending in an odoc block" `Quick test_ends_with_block;
    test_case "check_type_doc" `Quick test_check_type_doc;
  ]

let suite = ("docs", tests)
