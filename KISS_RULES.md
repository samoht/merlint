# Practical Rules Derived from KISS Principle

## 1. **Avoid Clever Code** (Potential Rule: E340)
```ocaml
(* BAD - Too clever *)
let factorial n = 
  List.fold_left ( * ) 1 (List.init n (fun i -> i + 1))

(* GOOD - Clear and simple *)
let rec factorial n =
  if n <= 0 then 1 else n * factorial (n - 1)
```

## 2. **No Nested Ternary/Match Expressions** (Potential Rule: E341)
```ocaml
(* BAD - Hard to follow *)
let status = 
  match user with
  | Some u -> (match u.role with Admin -> "admin" | User -> "user")
  | None -> "guest"

(* GOOD - Flat and clear *)
let status =
  match user with
  | Some { role = Admin; _ } -> "admin"
  | Some { role = User; _ } -> "user"
  | None -> "guest"
```

## 3. **Limit Function Parameters** (Potential Rule: E342)
```ocaml
(* BAD - Too many parameters *)
let create_user name email age city country phone role status =
  (* ... *)

(* GOOD - Use a record *)
type user_config = {
  name: string;
  email: string;
  age: int;
  city: string;
  country: string;
  phone: string;
  role: role;
  status: status;
}

let create_user config =
  (* ... *)
```

## 4. **No Complex Boolean Expressions** (Potential Rule: E343)
```ocaml
(* BAD - Hard to understand *)
if (not (user.age >= 18) || user.banned) && not admin && (user.country = "US" || user.country = "CA") then
  (* ... *)

(* GOOD - Extract to named functions *)
let is_underage user = user.age < 18
let is_north_american user = 
  match user.country with
  | "US" | "CA" -> true
  | _ -> false

let can_access user ~is_admin =
  not (is_underage user || user.banned) 
  && not is_admin 
  && is_north_american user

if can_access user ~is_admin:false then
  (* ... *)
```

## 5. **Avoid Deep Module Nesting** (Potential Rule: E344)
```ocaml
(* BAD - Too much nesting *)
module App = struct
  module Core = struct
    module Utils = struct
      module String = struct
        module Validators = struct
          let is_email = (* ... *)
        end
      end
    end
  end
end

(* GOOD - Flatter structure *)
module String_validators = struct
  let is_email = (* ... *)
end
```

## 6. **No Single-Letter Variable Names** (Potential Rule: E345)
Exception: Common idioms like `x`, `xs` for lists, `i` for indices
```ocaml
(* BAD *)
let f u p = 
  List.filter (fun x -> x.s = p) u

(* GOOD *)
let filter_by_status users status = 
  List.filter (fun user -> user.status = status) users
```

## 7. **Limit Match Expression Depth** (Potential Rule: E010 enhancement)
```ocaml
(* BAD - Too deeply nested *)
match x with
| Some y ->
    match y with
    | A z ->
        match z with
        | B w -> w
        | C _ -> default
    | D _ -> default
| None -> default

(* GOOD - Flatten or extract *)
let process_value = function
  | Some (A (B w)) -> w
  | Some (A (C _)) | Some (D _) | None -> default
```

## 8. **No Implicit Module Opens in Implementation** (Potential Rule: E346)
```ocaml
(* BAD *)
open List
open String
let process items = 
  map trim items  (* Which module? *)

(* GOOD *)
let process items = 
  List.map String.trim items  (* Clear origin *)
```

## 9. **Avoid Operator Soup** (Potential Rule: E347)
```ocaml
(* BAD *)
let result = x |> f >>= g <$> h @@ y

(* GOOD *)
let result = 
  let fx = f x in
  match fx with
  | None -> None
  | Some v -> Some (h (g v y))
```

## 10. **No Magic Numbers** (Potential Rule: E348)
```ocaml
(* BAD *)
if String.length password < 8 then
  Error "Too short"

(* GOOD *)
let min_password_length = 8

if String.length password < min_password_length then
  Error "Too short"
```

## Implementation Priority

High priority (directly improve readability):
- E342: Limit function parameters (max 4-5)
- E343: Complex boolean expressions
- E345: Single-letter variables
- E348: Magic numbers

Medium priority (improve maintainability):
- E341: Nested ternary/match
- E344: Deep module nesting
- E346: Implicit opens

Low priority (style preferences):
- E340: Clever code detection (hard to implement)
- E347: Operator soup (subjective)