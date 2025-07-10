# OCaml Testing Guide

This document outlines the testing conventions for OCaml projects, complementing the main style guide. These conventions ensure comprehensive test coverage and maintainable test code.

## Core Testing Philosophy

1. **1:1 Test Coverage** [E605, E610]: Every module in `lib/` should have a corresponding test module in `test/`.
2. **Test Organization** [E600]: Test files should export a `suite` value, not the module name.
3. **Test Inclusion** [E615]: All test suites must be included in the main test runner.
4. **Clear Test Names**: Test names should describe what they test, not how.
5. **Isolated Tests**: Each test should be independent and not rely on external state.

## Test File Structure

### Naming Convention
- For module `lib/foo.ml`, create test file `test/test_foo.ml`
- Test modules follow the pattern `Test_<module_name>`

### Basic Structure [E600]

```ocaml
(* test/test_user.ml *)
open Merlint

let test_create_user () =
  let user = User.create ~name:"Alice" ~email:"alice@example.com" in
  Alcotest.(check string) "user name" "Alice" (User.name user);
  Alcotest.(check string) "user email" "alice@example.com" (User.email user)

let test_user_validation () =
  let result = User.create ~name:"" ~email:"invalid" in
  Alcotest.(check bool) "empty name is invalid" true (Result.is_error result)

(* Export 'suite', not 'Test_user' *)
let suite =
  [
    ( "user",
      [
        Alcotest.test_case "create user" `Quick test_create_user;
        Alcotest.test_case "user validation" `Quick test_user_validation;
      ] );
  ]
```

## Test Runner Configuration [E615]

The main test runner (`test/test.ml`) must include all test suites:

```ocaml
(* test/test.ml *)
let () =
  let suites =
    Test_user.suite @ Test_config.suite @ Test_api.suite
    @ Test_database.suite @ Test_utils.suite
  in
  Alcotest.run "my_project" suites
```

## Test Coverage Requirements

### Module Coverage [E605, E610]
- Every library module must have tests
- Test files without corresponding library modules indicate orphaned tests
- Use `dune exec -- merlint` to check test coverage

### Function Coverage
- Test all public functions exposed in `.mli` files
- Include both success and error cases
- Test edge cases (empty inputs, large inputs, invalid data)

## Writing Good Tests

### Test Organization
Group related tests into logical suites:

```ocaml
let suite =
  [
    ("parsing", parsing_tests);
    ("validation", validation_tests);
    ("error_handling", error_tests);
  ]
```

### Test Data
Use helper functions to create test data:

```ocaml
let sample_user () =
  User.create ~name:"Test User" ~email:"test@example.com"

let invalid_emails = 
  ["no-at-sign"; "@missing-local"; "missing-domain@"; ""]
```

### Property-Based Testing
For complex logic, consider property-based testing with QCheck:

```ocaml
let test_parse_reverse () =
  QCheck.Test.make ~count:1000
    QCheck.string
    (fun s ->
      match Parser.parse s with
      | Ok ast -> Parser.to_string ast = s
      | Error _ -> true)
```

## Common Testing Patterns

### Testing Error Cases
```ocaml
let test_error_handling () =
  match problematic_function () with
  | Ok _ -> Alcotest.fail "Expected error but got success"
  | Error e ->
      Alcotest.(check string) "error message" 
        "Expected error message" (Error.to_string e)
```

### Testing Async Code (with Eio)
```ocaml
let test_async_operation () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let result = MyModule.async_operation ~sw env in
  Alcotest.(check string) "async result" "expected" result
```

### Testing with Mocks
```ocaml
module Mock_api = struct
  let get_user id =
    if id = "123" then Ok sample_user ()
    else Error `Not_found
end

let test_with_mock () =
  let module Service = User_service.Make(Mock_api) in
  let result = Service.find_user "123" in
  Alcotest.(check bool) "user found" true (Result.is_ok result)
```

## Test Quality Checklist

- [ ] All library modules have corresponding test files
- [ ] Test files export `suite`, not module names
- [ ] All test suites are included in the test runner
- [ ] Tests cover both success and failure cases
- [ ] Test names clearly describe what is being tested
- [ ] Tests are independent and can run in any order
- [ ] Complex logic has property-based tests
- [ ] No compiler warnings in test code

## Running Tests

```bash
# Run all tests
dune test

# Run tests and watch for changes
dune test -w

# Run tests with coverage
dune test --instrument-with bisect_ppx
bisect-ppx-report summary

# Run specific test suite
dune exec test/test_user.exe
```

## Continuous Integration

Ensure your CI pipeline runs:
1. `dune build` - Build the project
2. `dune test` - Run all tests  
3. `dune exec -- merlint` - Check code quality and test coverage
4. Coverage reporting (optional but recommended)