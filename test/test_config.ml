open Merlint

(* Testable config using our pp and equal functions *)
let config : Config.t Alcotest.testable =
  Alcotest.testable Config.pp Config.equal

let test_default_config () =
  let config = Config.default in
  Alcotest.check Alcotest.int "max_complexity" 10 config.max_complexity;
  Alcotest.check Alcotest.int "max_function_length" 50
    config.max_function_length;
  Alcotest.check Alcotest.int "max_nesting" 4 config.max_nesting;
  Alcotest.check Alcotest.bool "require_ocamlformat_file" true
    config.require_ocamlformat_file

let test_equal () =
  let config1 = Config.default in
  let config2 = Config.default in
  let config3 = { config1 with max_complexity = 20 } in

  Alcotest.check config "same configs are equal" config1 config2;
  Alcotest.check Alcotest.bool "different configs not equal" false
    (Config.equal config1 config3)

(* A temporary project holding a single [merlint.toml]. [Config.load] walks up
   from the directory it is handed, so the tree carries a [dune-project] to be
   a workspace root of its own. *)
let with_config content f =
  let tmp = Filename.temp_dir "merlint_config" "" in
  let write name text =
    Out_channel.with_open_text
      Fpath.(to_string (v tmp / name))
      (fun oc -> Out_channel.output_string oc text)
  in
  Fun.protect
    ~finally:(fun () ->
      ignore (Fmt.kstr Sys.command "rm -rf %s" (Filename.quote tmp)))
    (fun () ->
      write "dune-project" "(lang dune 3.0)";
      write "merlint.toml" content;
      f tmp)

(* [Config.load] on a config merlint must refuse, returning the message. *)
let refusal content =
  match with_config content (fun dir -> ignore (Config.load dir)) with
  | () ->
      Alcotest.failf
        "merlint.toml %S was accepted; an unknown key must be refused" content
  | exception Failure msg -> msg

let check_mentions msg text =
  Alcotest.check Alcotest.bool
    (Fmt.str "message mentions %S" text)
    true
    (Astring.String.is_infix ~affix:text msg)

(* A key merlint does not know is a typo or a key from a merlint that never
   existed. Accepting it silently makes the file read as configuration that is
   in force when none of it is. *)
let test_unknown_key_refused () =
  let msg = refusal "not-a-setting = 3\n" in
  check_mentions msg "not-a-setting";
  check_mentions msg "merlint.toml"

(* The dangerous shape: a near miss of a real key. [disallowed-modules] typed
   [disalowed-modules] leaves E221's ban list empty, so the rule the author
   configured never fires and every run is green for the wrong reason. The
   refusal names the key as written and points at the one meant. *)
let test_misspelled_key_refused () =
  let msg = refusal "disalowed-modules = [\"Stdlib.Printf\"]\n" in
  check_mentions msg "disalowed-modules";
  check_mentions msg "disallowed-modules"

(* A misspelt toggle is the same defect in the other direction: the author
   believes a rule is off for this tree and it is on, or believes a threshold
   is raised and it is the default. *)
let test_misspelled_toggle_refused () =
  let msg = refusal "max-complexty = 30\n" in
  check_mentions msg "max-complexty";
  check_mentions msg "max-complexity"

(* Every key merlint documents stays accepted -- including [workspace], which
   is read by {!Project} rather than {!Config}, and [acronyms], the alias for
   [allowed_words]. Refusing one of these would break real configs in the
   tree. *)
let all_keys =
  "max-complexity = 15\n\
   max-function-length = 100\n\
   max-nesting = 5\n\
   exempt-data-definitions = true\n\
   max-underscores-in-name = 2\n\
   min-name-length-underscore = 5\n\
   allowed_words = [\"EdDSA\"]\n\
   acronyms = [\"ECDSA\"]\n\
   topics = [\"org:blacksun\"]\n\
   allowed_states = [\"Sender\"]\n\
   allowed-names = [\"object'\"]\n\
   disallowed_modules = [\"Stdlib.Printf\"]\n\
   disallowed_libraries = [\"fmt\"]\n\
   allow-obj-magic = false\n\
   allow-str-module = false\n\
   allow-catch-all-exceptions = false\n\
   require-ocamlformat-file = true\n\
   require-mli-files = true\n\
   workspace = \".\"\n\n\
   [[rules]]\n\
   files = \"lib/*.ml\"\n\
   exclude = [\"E100\"]\n"

let test_documented_keys_accepted () =
  with_config all_keys @@ fun dir ->
  let loaded = Config.load dir in
  Alcotest.check Alcotest.int "max-complexity applied" 15 loaded.max_complexity;
  Alcotest.check Alcotest.int "max-nesting applied" 5 loaded.max_nesting;
  Alcotest.check
    Alcotest.(list string)
    "allowed_words and acronyms both land" [ "ECDSA"; "EdDSA" ]
    (List.sort String.compare loaded.allowed_words);
  Alcotest.check
    Alcotest.(list string)
    "disallowed_modules applied" [ "Stdlib.Printf" ] loaded.disallowed_modules

let tests =
  [
    Alcotest.test_case "default_config" `Quick test_default_config;
    Alcotest.test_case "equal" `Quick test_equal;
    Alcotest.test_case "unknown key refused" `Quick test_unknown_key_refused;
    Alcotest.test_case "misspelled key refused" `Quick
      test_misspelled_key_refused;
    Alcotest.test_case "misspelled toggle refused" `Quick
      test_misspelled_toggle_refused;
    Alcotest.test_case "documented keys accepted" `Quick
      test_documented_keys_accepted;
  ]

let suite = ("config", tests)
