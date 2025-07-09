# Testing Guide

This document outlines the testing conventions for this project. The goal is to
ensure the codebase is robust and maintainable.

## Core Philosophy

1.  **Unit Tests First**: Prioritize unit tests for individual modules and
    functions.
2.  **Test-Driven Development (TDD)**: While not strictly enforced, TDD is
    encouraged.

## Tooling

-   **Test Framework**: We use `Alcotest` for all tests.
-   **Test Runner**: Tests are executed via `dune`.

## Test Structure

A common way to structure tests is to categorize them, for example, by
functionality (e.g., core API) or by layer (e.g., UI).

-   **`test/test.ml`**: A main test runner can aggregate test suites from
    individual `test_*.ml` files.
-   **`test/test_*.ml`**: Each `test_*.ml` file contains the tests for a
    specific module. For example, `test/test_users.ml` would contain tests for
    a `User` module.
-   **`test/dune`**: Defines the test executable.

### Individual Test Files

Each `test_*.ml` file should export a `suite` value of type
`(string * Alcotest.test_case list) list`.

The `suite` is a list of `(name, test_cases)` tuples, where:

-   `name` is the name of the test suite (e.g., `"users"`).
-   `test_cases` is a list of `Alcotest.test_case` values.

#### Test Naming Convention

**Use short, meaningful names for both test suites and test cases:**

-   Test suite names should be lowercase, single words (e.g., `"users"`,
    `"slack"`, `"commands"`)
-   Test case names should be lowercase with underscores, concise but
    descriptive (e.g., `"list"`, `"create"`, `"parse_error"`,
    `"tab_complete"`)
-   Avoid redundant prefixes in test case names when the context is clear from
    the suite name
-   Keep names short enough to be easily typed on the command line when running
    individual tests

### Assertions

We use `Alcotest.check` to make assertions in our tests. `Alcotest.check` takes
a `testable`, an `expected` value, and an `actual` value.

```ocaml
Alcotest.check Alcotest.int "number of users" 3 (List.length response_users)
```

Here's an example from a hypothetical `test/test_users.ml`:

```ocaml
(* test/test_users.ml *)

let test_list_users () =
  (* ... *)

let test_user_info () =
  (* ... *)

let tests =
  [
    Alcotest.test_case "list" `Quick test_list_users;
    Alcotest.test_case "info" `Quick test_user_info;
  ]

let suite = [ ("users", tests) ]
```

### End-to-End Testing with Cram

Cram tests are essential for verifying the behavior of the final, compiled
executable. They provide the highest level of confidence that the application
works as expected for the end-user.

#### Best Practices

##### 1. Use Cram Directories, Not Files

To keep tests organized and self-contained, every Cram test should be a
directory ending in `.t`. This allows you to include helper scripts,
configuration files, or even small dune projects within the test itself.

**GOOD**: Create a directory structure:
```
test/cram/
└── my_feature.t/
    ├── run.t           # The main cram test script
    └── helper_data.txt # Any data files needed by the test
```

**AVOID**: Creating a single `my_feature.t` file at the top level of
`test/cram/`.

##### 2. Create Actual Test Files

To ensure tests are clear and easy to debug, all source code and configuration
used by a test should be real files within the test directory. Avoid embedding
code within the `run.t` script using `cat > file << EOF`. This makes the test
harder to read, write, and maintain.

**GOOD**: Create real files in the test directory structure that can be
referenced by the test script.
```
test/cram/my_other_feature.t/
├── run.t
├── dune-project
└── bin/
    ├── dune
    └── main.ml
```
Then, in `run.t`, you can build and run this self-contained project:
```cram
  $ dune build
  $ dune exec my_other_feature
  Hello from the test!
  [0]
```

**AVOID**: Using `cat > file << EOF` patterns in cram tests. This is hard to
read and maintain.
```cram
  $ cat > my_program.ml << EOF
  > let () = print_endline "Hello"
  > EOF
  $ ocaml my_program.ml
  Hello
  [0]
```

### Running Tests

To run all tests, use the `dune runtest` alias:

```bash
dune runtest
```

To run a specific test executable:

```bash
dune exec test/test.exe
```

To run individual test suites or cases:

```bash
dune exec -- test/test.exe test users <n> -v
```

