(** Style guide document structure *)

(* Guide module - uses Issue.kind for issue types *)

type element =
  | Title of string
  | Section of string * element list
  | Paragraph of string
  | Code of string  (** Code examples *)
  | Rule of Issue.kind

let content =
  [
    Title "OCaml Coding Style Guide";
    Paragraph
      {|This document outlines the coding and testing conventions for this project. The goal is to ensure the codebase is clear, robust, and maintainable. The style is inspired by the best practices of the modern OCaml ecosystem, emphasizing modularity and pragmatism.|};
    Section
      ( "Core Philosophy",
        [
          Paragraph
            "1. **Interface-First Design**: Always start by designing the \
             module's interface in the `.mli` file. A clean interface is more \
             critical than a clever implementation.";
          Paragraph
            "2. **Modularity**: Build small, focused modules that do one thing \
             well. Compose them to build larger systems.";
          Paragraph
            "3. **Simplicity and Clarity (KISS)**: Prioritize clarity over \
             conciseness. Strive for the simplest possible solution and avoid \
             overly clever or obscure constructs.";
          Paragraph
            "4. **Explicitness**: Make control flow and error handling \
             explicit. Avoid exceptions for recoverable errors.";
          Paragraph
            "5. **Purity and Side-Effect Management**: Prefer pure functions. \
             Isolate side-effects (I/O, state mutation) at the edges of the \
             application. This is a fundamental principle for building \
             maintainable, testable, and composable systems.";
          Paragraph
            "6. **Be Deliberate with Dependencies**: Every dependency has a \
             cost - maintenance burden, increased compile times, and expanded \
             API surface. Before adding a new dependency, consider if the \
             functionality can be achieved with existing tools or a small \
             amount of code. When you do add dependencies, choose \
             high-quality, well-maintained libraries.";
          Paragraph
            {|7. **NEVER USE Obj.magic**: The `Obj` module is not part of the OCaml language and breaks type safety. There is always a better, type-safe solution.|};
          Rule Obj_magic;
        ] );
    Section
      ( "Dependencies and Tooling",
        [
          Paragraph
            "**Build System**: The project is built exclusively with `dune`.";
          Paragraph
            "**Formatting**: All code is formatted automatically with \
             `ocamlformat`. Run `dune fmt` before committing. Ensure you have \
             a `.ocamlformat` file in your project root.";
          Rule Missing_ocamlformat_file;
          Paragraph
            "**Core Libraries**: Projects typically embrace a curated set of \
             high-quality libraries for common tasks. For example:";
          Paragraph "- **Concurrency**: `eio`";
          Paragraph "- **Structured Output**: `fmt` (instead of Printf/Format)";
          Rule Printf_module;
          Paragraph "- **Regular Expressions**: `re` (instead of Str module)";
          Rule Str_module;
          Paragraph "- **Logging**: `logs`";
          Paragraph "- **CLI Parsing**: `cmdliner`";
          Paragraph "- **JSON Handling**: `yojson`";
          Paragraph "- **HTTP**: `cohttp-eio`";
          Paragraph "- **Test Framework**: `Alcotest`";
        ] );
    Section
      ( "Module and Interface Design",
        [
          Paragraph
            "**Documentation**: Every `.mli` file must begin with a top-level \
             documentation comment explaining its purpose. Focus on *what* the \
             module provides, not *how* it is implemented.";
          Rule Missing_mli_doc;
          Code
            {|(** User API

    This module provides types and functions for interacting with users. *)|};
          Paragraph
            "**Interface (`.mli`) Style**: Document every exported value. Use \
             a consistent, concise style.";
          Rule Missing_value_doc;
          Paragraph
            "**Documentation Philosophy**: For functions, use the \
             `[function_name arg1 arg2] is ...` pattern.";
          Code
            {|val is_bot : t -> bool
(** [is_bot u] is [true] if [u] is a bot user. *)|};
          Paragraph "For values, describe what the value represents.";
          Code {|type id = string
(** A user identifier. *)|};
          Paragraph
            "**Abstract Types**: Keep types abstract (`type t`) whenever \
             possible. Expose smart constructors and accessors instead of \
             record fields to maintain invariants.";
          Paragraph
            "**Standard Interfaces for Data Types**: For modules defining a \
             central data type `t`, consistently provide these functions where \
             applicable:";
          Rule Missing_standard_function;
          Paragraph
            "- `val v : ... -> t`: A pure, smart constructor for creating \
             values of type `t` in memory. This function should not perform \
             any I/O.";
          Paragraph
            "- `val create : ... -> (t, Error.t) result`: A function that \
             performs a side-effect, like an API call, to create a resource.";
          Paragraph
            "- `val pp : t Fmt.t`: A pretty-printer for logging and debugging.";
          Paragraph
            "- `val equal : t -> t -> bool`: A structural equality function.";
          Paragraph
            "- `val compare : t -> t -> int`: A comparison function for \
             sorting.";
          Paragraph
            "- `val of_json : Yojson.Safe.t -> (t, string) result`: For \
             parsing from JSON.";
          Paragraph
            "- `val to_json : t -> Yojson.Safe.t`: For serializing to JSON.";
          Paragraph
            "- `val validate : t -> (t, string) result`: For validating the \
             integrity of the data.";
        ] );
    Section
      ( "Project Structure",
        [
          Paragraph
            "**Interface Files**: Create `.mli` files for all public modules \
             to define clear interfaces and hide implementation details.";
          Rule Missing_mli_file;
          Paragraph
            "**Code Formatting**: Maintain a `.ocamlformat` file in the \
             project root with consistent formatting settings.";
          Rule Missing_ocamlformat_file;
        ] );
    Section
      ( "Command-Line Applications",
        [
          Paragraph
            "For command-line applications in the `bin/` directory, it's \
             common to use a library like `Cmdliner`.";
          Paragraph
            "**Shared Functionality**: Common functionality, such as \
             authentication and logging setup, can be placed in a shared \
             module (e.g., `bin/common.ml`).";
          Paragraph
            "**`run` function**: A shared module might provide a `run` \
             function that initializes the application's main loop and \
             environment (e.g., an Eio loop). This should be used by all \
             commands to ensure a consistent environment.";
        ] );
    Section
      ( "Error Handling",
        [
          Paragraph
            "We use the `result` type for all recoverable errors. Exceptions \
             are reserved for programming errors (e.g., `Invalid_argument`).";
          Paragraph
            "**Central Error Type**: Define a single, comprehensive error type \
             for the library (e.g., in `lib/error.ml`).";
          Code
            {|(* In lib/error.mli *)
type t = [
  | `Api of string * Yojson.Safe.t (* code, fields *)
  | `Json_parse of string
  | `Network of string
  | `Msg of string
]

val pp : t Fmt.t|};
          Paragraph
            "**Error Helpers**: In implementation files, use helper functions \
             to construct errors. This ensures consistency.";
          Code
            {|(* In an implementation file *)
let err_api code fields = Error (`Api (code, fields))
let err_parse msg = Error (`Json_parse msg)

let find_user_id json =
  match Yojson.Safe.Util.find_opt "id" json with
  | Some (`String id) -> Ok id
  | Some _ -> err_parse "Expected string for user ID"
  | None -> err_parse "Missing user ID"|};
          Paragraph
            "**No Broad Exceptions**: Never use `try ... with _ -> ...`. \
             Always match on specific exceptions.";
          Rule Catch_all_exception;
          Paragraph
            "**No Silenced Warnings**: Fix underlying issues instead of \
             silencing compiler warnings with attributes like `[@warning \
             \"-nn\"]`.";
          Rule Silenced_warning;
          Paragraph
            "**Initialization Failures**: For unrecoverable errors during \
             startup (e.g., missing configuration), it is acceptable to fail \
             fast using `Fmt.failwith`.";
          Code
            {|let tls_config =
  match Tls.Config.client ~authenticator () with
  | Ok config -> config
  | Error (`Msg msg) -> Fmt.failwith "Failed to create TLS config: %s" msg|};
        ] );
    Section
      ( "Naming and Formatting",
        [
          Paragraph
            "**File Naming**: Lowercase with underscores (e.g., \
             `user_profile.ml`).";
          Paragraph
            "**Module Naming**: Lowercase with underscores (e.g., \
             `user_profile`).";
          Rule Module_naming;
          Paragraph
            "**Type Naming**: The primary type in a module is `t`. Identifiers \
             are named `id`. Use snake_case for all type names.";
          Rule Type_naming;
          Paragraph
            "**Variant Constructors**: Use Snake_case for variant constructors \
             (e.g., `Waiting_for_input`, `Processing_data`), not CamelCase.";
          Rule Variant_naming;
          Paragraph
            "**Values**: Short, descriptive, and lowercase with underscores \
             (e.g., `find_user`, `create_channel`).";
          Rule Value_naming;
          Paragraph
            "**Long Identifiers**: Avoid excessively long names with many \
             underscores. Keep names concise and meaningful.";
          Rule Long_identifier;
          Paragraph
            "**Function Naming**: Use `get_*` for extraction (returns value \
             directly), `find_*` for search (returns option type).";
          Rule Function_naming;
          Paragraph
            "**Labels**: Use labels only when they clarify the meaning of an \
             argument, not for all arguments. Avoid `~f` and `~x`.";
          Paragraph "**Formatting**: Trust `ocamlformat`. No manual formatting.";
        ] );
    Section
      ( "API Design",
        [
          Paragraph
            "**Avoid Boolean Blindness**: Never use multiple boolean arguments \
             in a function - they make call sites ambiguous and error-prone. \
             Instead, use explicit variant types that leverage OCaml's type \
             system for clarity.";
          Code
            {|(* BAD - Boolean blindness *)
let create_widget visible bordered = ...
let w = create_widget true false  (* What does this mean? *)

(* GOOD - Explicit variants *)
type visibility = Visible | Hidden
type border = With_border | Without_border
let create_widget ~visibility ~border = ...
let w = create_widget ~visibility:Visible ~border:Without_border|};
          Paragraph
            "**Use Phantom Types for Safety**: When appropriate, use phantom \
             types to enforce invariants at compile time rather than runtime.";
          Paragraph
            "**Builder Pattern for Complex Configuration**: For functions with \
             many optional parameters, consider using a builder pattern with a \
             record type rather than many optional arguments.";
        ] );
    Section
      ( "Function Design",
        [
          Paragraph
            "**Keep Functions Small and Focused**: A function should do one \
             thing well. Decompose complex logic into smaller, well-defined \
             helper functions. This improves readability, testability, and \
             reusability. Aim for functions under 50 lines. As a rule of \
             thumb, avoid deep nesting of `match` or `if` statements; more \
             than two or three levels is a strong signal that the function \
             should be refactored.";
          Rule Function_length;
          Rule Deep_nesting;
          Paragraph
            "**Complexity Management**: Break down functions with high \n\
            \             cyclomatic complexity into smaller, focused helper \
             functions with \n\
            \             clear names.";
          Rule Complexity;
          Paragraph
            "**Composition over Abstraction**: Favor the composition of small, \n\
            \             concrete functions to build up complex behavior. \
             Avoid deep \n\
            \             abstractions and complex class hierarchies.";
          Paragraph
            "**Data-Oriented Design**: Design functions to operate on simple, \n\
            \             immutable data structures (records, variants, etc.). \
             Avoid \n\
            \             creating complex objects with hidden internal state.";
          Paragraph
            "**Avoid Premature Generalization**: Write code that solves the \n\
            \             problem at hand. Avoid adding unnecessary complexity \
             or \n\
            \             generality that is not required by the current needs \
             of the \n\
            \             project.";
        ] );
    Section
      ( "Logging",
        [
          Paragraph
            "Effective logging is crucial for debugging and monitoring. We use \
             the `logs` library for all logging.";
          Paragraph
            "**Log Source**: Each module should define its own log source.";
          Code
            {|let log_src = Logs.Src.create "project_name.module_name"
module Log = (val Logs.src_log log_src : Logs.LOG)|};
          Paragraph
            "**Log Levels**: Use the following log levels appropriately:";
          Paragraph
            "- `Log.app`: For messages that should always be shown to the user \
             (e.g., startup messages).";
          Paragraph
            "- `Log.err`: For errors that have been handled but are critical \
             enough to report.";
          Paragraph
            "- `Log.warn`: For potential issues that do not prevent the \
             current operation from completing.";
          Paragraph
            "- `Log.info`: For informational messages about the application's \
             state.";
          Paragraph
            "- `Log.debug`: For detailed, verbose messages useful for \
             debugging.";
          Paragraph
            "**Structured Logging**: Use tags to add structured context to log \
             messages. This is especially useful for machine-readable logs.";
          Code
            {|Log.info (fun m ->
    m "Received event: %s" event_type
      ~tags:(Logs.Tag.add "channel_id" channel_id Logs.Tag.empty))|};
        ] );
    Section
      ( "Testing",
        [
          Section
            ( "Core Testing Philosophy",
              [
                Paragraph
                  "1. **Unit Tests First**: Prioritize unit tests for \
                   individual modules and functions.";
                Paragraph
                  "2. **1:1 Test Coverage**: Every module in `lib/` should \
                   have a corresponding test module in `test/`.";
                Rule Missing_test_file;
                Rule Test_without_library;
                Paragraph
                  "3. **Test Organization**: Test files should export a \
                   `suite` value.";
                Rule Test_exports_module;
                Paragraph
                  "4. **Test Inclusion**: All test suites must be included in \
                   the main test runner.";
                Rule Test_suite_not_included;
                Paragraph
                  "5. **Clear Test Names**: Test names should describe what \
                   they test, not how.";
                Paragraph
                  "6. **Isolated Tests**: Each test should be independent and \
                   not rely on external state.";
              ] );
          Section
            ( "Test Structure",
              [
                Paragraph
                  "**`test/test.ml`**: A main test runner that aggregates test \
                   suites from individual `test_*.ml` files.";
                Paragraph
                  "**`test/test_*.ml`**: Each `test_*.ml` file contains the \
                   tests for a specific module.";
                Paragraph "**`test/dune`**: Defines the test executable.";
              ] );
          Paragraph
            "**Individual Test Files**: Each `test_*.ml` file should export a \
             `suite` value of type `(string * Alcotest.test_case list) list`.";
          Paragraph "**Test Naming Convention**:";
          Paragraph
            "- Test suite names should be lowercase, single words (e.g., \
             `\"users\"`, `\"commands\"`)";
          Paragraph
            "- Test case names should be lowercase with underscores, concise \
             but descriptive (e.g., `\"list\"`, `\"create\"`, \
             `\"parse_error\"`)";
          Section
            ( "Writing Good Tests",
              [
                Paragraph
                  "**Function Coverage**: Test all public functions exposed in \
                   `.mli` files, including success, error, and edge cases.";
                Paragraph
                  "**Test Data**: Use helper functions to create test data.";
                Paragraph
                  "**Property-Based Testing**: For complex logic, consider \
                   property-based testing with QCheck.";
              ] );
          Section
            ( "End-to-End Testing with Cram",
              [
                Paragraph
                  "Cram tests are essential for verifying the behavior of the \
                   final executable.";
                Paragraph
                  "**Use Cram Directories**: Every Cram test should be a \
                   directory ending in `.t` (e.g., `my_feature.t/`).";
                Paragraph
                  "**Create Actual Test Files**: Avoid embedding code within \
                   the `run.t` script using `cat > file << EOF`. Create real \
                   source files within the test directory.";
              ] );
          Section
            ( "Running Tests",
              [
                Code
                  {|# Run all tests
dune test

# Run tests and watch for changes
dune test -w

# Run tests with coverage
dune test --instrument-with bisect_ppx
bisect-ppx-report summary|};
              ] );
        ] );
    Section
      ( "Commit Messages",
        [
          Paragraph
            "We follow a structured format for commit messages to ensure they \
             are clear, informative, and easy to read. A good commit message \
             provides context for why a change was made.";
          Section
            ( "Format",
              [
                Paragraph
                  "A commit message consists of a short, imperative title \
                   followed by a more detailed body.";
                Paragraph
                  "**Title**: A single, concise line summarizing the change.";
                Paragraph "- Keep it under 50 characters.";
                Paragraph
                  "- Use the imperative mood (e.g., \"Add feature\" not \
                   \"Added feature\")";
                Paragraph "- Do not end the title with a period.";
                Paragraph
                  "**Body**: A detailed explanation of the change, separated \
                   from the title by a blank line.";
                Paragraph "- Wrap the body at 72 characters.";
                Paragraph
                  "- The body should be structured into paragraphs that \
                   implicitly answer three questions:";
                Paragraph "  1. **What** does this change do?";
                Paragraph "  2. **Why** was this change necessary?";
                Paragraph "  3. **How** was this change implemented?";
              ] );
          Section
            ( "Example",
              [
                Code
                  {|feat(parser): Add support for parsing logical operators

This change introduces the capability to parse logical `AND` and `OR`
operators in the expression language. It extends the lexer to
recognize `&&` and `||` and updates the parser with new rules for
logical expressions.

The expression language previously lacked support for combining
conditions, which was a significant limitation for writing complex
business rules. This feature was requested by users to allow for more
flexible and powerful queries.

The implementation involved extending the lexer's token set with `AND`
and `OR` tokens and updating the parser's precedence rules. New AST
nodes for `LogicalAnd` and `LogicalOr` were added, and the evaluator
was updated to handle them.|};
              ] );
          Section
            ( "AI Assistants",
              [
                Paragraph
                  "AI assistants may be used to help write code, but the final \
                   commit must be authored by a human developer. Do not use \
                   `Co-authored-by:` trailers for AI assistants.";
              ] );
        ] );
  ]
