# OCaml Style Guide

This document outlines the coding conventions for this project. The goal is to
ensure the codebase is clear, robust, and maintainable. The style is inspired
by the best practices of the modern OCaml ecosystem, emphasizing modularity and
pragmatism.

## Core Philosophy

1.  **Interface-First Design**: Always start by designing the module's
    interface in the `.mli` file. A clean interface is more critical than a
    clever implementation.
2.  **Modularity**: Build small, focused modules that do one thing well. Compose
    them to build larger systems.
3.  **Simplicity and Clarity (KISS)**: Prioritize clarity over conciseness.
    Strive for the simplest possible solution and avoid overly clever or obscure
    constructs.
4.  **Explicitness**: Make control flow and error handling explicit. Avoid
    exceptions for recoverable errors.
5.  **NEVER USE Obj.magic** [E100]: The `Obj` module is not part of the OCaml language
    and breaks type safety. There is always a better, type-safe solution.

## Dependencies and Tooling

-   **Build System**: The project is built exclusively with `dune`.
-   **Formatting** [E500]: All code is formatted automatically with `ocamlformat`. Run
    `dune fmt` before committing. Ensure you have a `.ocamlformat` file in your project root.
-   **Core Libraries**: Projects typically embrace a curated set of high-quality
    libraries for common tasks. For example:
    -   **Concurrency**: `eio`
    -   **Structured Output** [E205]: `fmt` (instead of Printf/Format)
    -   **Regular Expressions** [E200]: `re` (instead of Str module)
    -   **Logging**: `logs`
    -   **CLI Parsing**: `cmdliner`
    -   **JSON Handling**: `yojson`
    -   **HTTP**: `cohttp-eio`

## Module and Interface Design

-   **Documentation** [E400]: Every `.mli` file must begin with a top-level
    documentation comment explaining its purpose. Focus on *what* the module
    provides, not *how* it is implemented.

    ```ocaml
    (** User API

        This module provides types and functions for interacting with users. *)
    ```

-   **Interface (`.mli`) Style** [E405]: Document every exported value. Use a
    consistent, concise style.
    -   **Documentation Philosophy**: For functions, use the
        `[function_name arg1 arg2] is ...` pattern.
        ```ocaml
        val is_bot : t -> bool
        (** [is_bot u] is [true] if [u] is a bot user. *)
        ```
    -   For values, describe what the value represents.
        ```ocaml
        type id = string
        (** A user identifier. *)
        ```

-   **Abstract Types**: Keep types abstract (`type t`) whenever possible. Expose
    smart constructors and accessors instead of record fields to maintain
    invariants.

-   **Standard Interfaces for Data Types** [E415]: For modules defining a central data
    type `t`, consistently provide these functions where applicable:
    -   `val v : ... -> t`: A pure, smart constructor for creating values of
        type `t` in memory. This function should not perform any I/O.
    -   `val create : ... -> (t, Error.t) result`: A function that performs a
        side-effect, like an API call, to create a resource.
    -   `val pp : t Fmt.t`: A pretty-printer for logging and debugging.
    -   `val equal : t -> t -> bool`: A structural equality function.
    -   `val compare : t -> t -> int`: A comparison function for sorting.
    -   `val of_json : Yojson.Safe.t -> (t, string) result`: For parsing from
        JSON.
    -   `val to_json : t -> Yojson.Safe.t`: For serializing to JSON.
    -   `val validate : t -> (t, string) result`: For validating the integrity
        of the data.

## Project Structure

-   **Interface Files** [E505]: Create `.mli` files for all public modules to define
    clear interfaces and hide implementation details.
-   **Code Formatting** [E500]: Maintain a `.ocamlformat` file in the project root
    with consistent formatting settings.

## Command-Line Applications

For command-line applications in the `bin/` directory, it's common to use a
library like `Cmdliner`.

-   **Shared Functionality**: Common functionality, such as authentication and
    logging setup, can be placed in a shared module (e.g., `bin/common.ml`).
-   **`run` function**: A shared module might provide a `run` function that
    initializes the application's main loop and environment (e.g., an Eio
    loop). This should be used by all commands to ensure a consistent
    environment.

## Error Handling

We use the `result` type for all recoverable errors. Exceptions are reserved
for programming errors (e.g., `Invalid_argument`).

-   **Central Error Type**: Define a single, comprehensive error type for the
    library (e.g., in `lib/error.ml`).

    ```ocaml
    (* In lib/error.mli *)
    type t = [
      | `Api of string * Yojson.Safe.t (* code, fields *)
      | `Json_parse of string
      | `Network of string
      | `Msg of string
    ]

    val pp : t Fmt.t
    ```

-   **Error Helpers**: In implementation files, use helper functions to
    construct errors. This ensures consistency.

    ```ocaml
    (* In an implementation file *)
    let err_api code fields = Error (`Api (code, fields))
    let err_parse msg = Error (`Json_parse msg)

    let find_user_id json =
      match Yojson.Safe.Util.find_opt "id" json with
      | Some (`String id) -> Ok id
      | Some _ -> err_parse "Expected string for user ID"
      | None -> err_parse "Missing user ID"
    ```

-   **No Broad Exceptions** [E105]: Never use `try ... with _ -> ...`. Always match on
    specific exceptions.
-   **No Silenced Warnings** [E110]: Fix underlying issues instead of silencing compiler
    warnings with attributes like `[@warning "-nn"]`.

-   **Initialization Failures**: For unrecoverable errors during startup (e.g.,
    missing configuration), it is acceptable to fail fast using `Fmt.failwith`.

    ```ocaml
    let tls_config =
      match Tls.Config.client ~authenticator () with
      | Ok config -> config
      | Error (`Msg msg) -> Fmt.failwith "Failed to create TLS config: %s" msg
    ```

## Naming and Formatting

-   **File Naming**: Lowercase with underscores (e.g., `user_profile.ml`).
-   **Module Naming** [E305]: Lowercase with underscores (e.g., `user_profile`).
-   **Type Naming** [E315]: The primary type in a module is `t`. Identifiers are named
    `id`. Use snake_case for all type names.
-   **Variant Constructors** [E300]: Use Snake_case for variant constructors (e.g.,
    `Waiting_for_input`, `Processing_data`), not CamelCase.
-   **Values** [E310]: Short, descriptive, and lowercase with underscores (e.g.,
    `find_user`, `create_channel`).
-   **Long Identifiers** [E320]: Avoid excessively long names with many underscores.
    Keep names concise and meaningful.
-   **Function Naming** [E325]: Use `get_*` for extraction (returns value directly),
    `find_*` for search (returns option type).
-   **Labels**: Use labels only when they clarify the meaning of an argument, not
    for all arguments. Avoid `~f` and `~x`.
-   **Formatting**: Trust `ocamlformat`. No manual formatting.

## Function Design

-   **Keep Functions Small and Focused** [E005]: A function should do one thing well.
    Decompose complex logic into smaller, well-defined helper functions. This
    improves readability, testability, and reusability. Aim for functions under
    50 lines. As a rule of thumb, avoid deep nesting of `match` or `if` statements;
    more than two or three levels [E010] is a strong signal that the function should be
    refactored.
-   **Complexity Management** [E001]: Break down functions with high cyclomatic complexity
    into smaller, focused helper functions with clear names.
-   **Purity**: Prefer pure functions. Isolate side-effects (I/O, state
    mutation) at the edges of the application, primarily in the `bin/` and
    `lib/ui/` directories.
-   **Composition over Abstraction**: Favor the composition of small, concrete
    functions to build up complex behavior. Avoid deep abstractions and complex
    class hierarchies.
-   **Data-Oriented Design**: Design functions to operate on simple, immutable
    data structures (records, variants, etc.). Avoid creating complex objects
    with hidden internal state.
-   **Avoid Premature Generalization**: Write code that solves the problem at
    hand. Avoid adding unnecessary complexity or generality that is not required
    by the current needs of the project.

## Logging

Effective logging is crucial for debugging and monitoring. We use the `logs`
library for all logging.

-   **Log Source**: Each module should define its own log source.

    ```ocaml
    let log_src = Logs.Src.create "project_name.module_name"
    module Log = (val Logs.src_log log_src : Logs.LOG)
    ```

-   **Log Levels**: Use the following log levels appropriately:
    -   `Log.app`: For messages that should always be shown to the user (e.g.,
        startup messages).
    -   `Log.err`: For errors that have been handled but are critical enough to
        report.
    -   `Log.warn`: For potential issues that do not prevent the current
        operation from completing.
    -   `Log.info`: For informational messages about the application's state.
    -   `Log.debug`: For detailed, verbose messages useful for debugging.

-   **Structured Logging**: Use tags to add structured context to log messages.
    This is especially useful for machine-readable logs.

    ```ocaml
    Log.info (fun m ->
        m "Received event: %s" event_type
          ~tags:(Logs.Tag.add "channel_id" channel_id Logs.Tag.empty))
    ```

## Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/)
specification. This creates a clear and browsable commit history.

-   **Format**: `type(scope): subject`
    -   **type**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
    -   **scope**: The module or part of the codebase affected (e.g., `user`,
        `api`, `ui`).
    -   **subject**: A concise, imperative description of the change.

-   **Examples**:
    -   `feat(api): add support for file uploads`
    -   `fix(ui): correct channel list rendering bug`
    -   `docs(readme): update installation instructions`
    -   `test(user): add tests for user profile updates`

-   **AI Assistants**: AI assistants may be used to help write code, but the
    final commit must be authored by a human developer. Do not use
    `Co-authored-by:` trailers for AI assistants.
