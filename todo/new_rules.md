# Proposed New Rules for OCaml Style Guide

This document outlines proposed new rules to enhance the existing OCaml style guide, making it more comprehensive and aligned with modern best practices for safe and maintainable systems programming.

---

### 1. API Design and Module Structure

#### [E420] Avoid Exporting Simple Module Aliases

*   **Description**: In an interface (`.mli`) file, avoid creating simple aliases for other modules, such as `module Foo = Bar`. This practice clutters the API and can be confusing for users, who should be encouraged to use the original module (`Bar`) directly.
*   **Rationale**: Exporting a module alias provides no new functionality and can create ambiguity about whether the alias is a distinct module with different properties. Keeping the API clean and direct improves usability.
*   **Good Example**:
    ```ocaml
    (* In http.mli *)
    module Request = Http_request
    module Response = Http_response
    (* User should just use Http_request and Http_response directly. *)
    ```
*   **Bad Example**:
    ```ocaml
    (* In http.mli *)
    (* (No aliases - user directly accesses other modules) *)
    ```

#### [E425] Define and Expose Functor Signatures

*   **Description**: When defining a functor in an `.mli` file, its argument and return types should be explicitly defined with clear signatures. Avoid exposing anonymous or inline functor types in interfaces.
*   **Rationale**: Explicit functor signatures are essential for documentation and usability. They clarify the contract of the functor, making it clear what kind of modules it accepts and what kind of module it produces.
*   **Good Example**:
    ```ocaml
    (* In store.mli *)
    module type Key = sig
      type t
      val equal : t -> t -> bool
    end

    module Make (K : Key) : sig
      type key = K.t
      type 'a t
      val find : 'a t -> key -> 'a option
    end
    ```
*   **Bad Example**:
    ```ocaml
    (* In store.mli *)
    module Make : functor (K : sig type t ... end) -> sig ... end
    ```

#### [E360] Define Custom Operators in a Scoped Module

*   **Description**: Custom infix operators (e.g., `>>=`, `let*`, `|->`) should not be defined at the top level of a module. Instead, they should be placed within a dedicated, scoped module, such as `Syntax`, `Infix`, or `Let_syntax`.
*   **Rationale**: This practice prevents polluting the global namespace and forces the user to explicitly `open` the syntax module to enable the operators. This makes code clearer and avoids conflicts between libraries that might define the same operator.
*   **Good Example**:
    ```ocaml
    module Result = struct
      type ('a, 'e) t = ('a, 'e) result
      module Syntax = struct
        let (let*) = Result.bind
      end
    end

    (* Usage *)
    let (let*) = Result.Syntax.(let*) in
    ...
    ```
*   **Bad Example**:
    ```ocaml
    module Result = struct
      type ('a, 'e) t = ('a, 'e) result
      let (let*) = Result.bind (* Defined at the top level *)
    end
    ```

---

### 2. Type and Data Structure Definitions

#### [E316] Prefer Private Types over Concrete Record Types in MLIs

*   **Description**: In `.mli` files, prefer marking record types as `private` (e.g., `type t = private { ... }`). This prevents users from directly constructing or modifying record fields, forcing them to use your provided helper functions.
*   **Rationale**: Abstract types (`type t`) can be too restrictive, while concrete types (`type t = { ... }`) break encapsulation and allow users to violate invariants. Private types offer a perfect middle ground, allowing controlled construction while protecting internal invariants.
*   **Good Example**:
    ```ocaml
    (* In user.mli *)
    type t = private { id: int; name: string }
    val make : id:int -> name:string -> t
    val name : t -> string
    ```
*   **Bad Example**:
    ```ocaml
    (* In user.mli *)
    type t = { id: int; name: string } (* Invariants can be broken *)
    ```

#### [E317] Avoid Extensible Variants in Public APIs

*   **Description**: Avoid using extensible variants (`type t += ...`) for core data types in public-facing library interfaces.
*   **Rationale**: Extensible variants allow downstream consumers to add new constructors to your type. While powerful for plugin architectures, this can break a library's internal logic, which may assume it knows all possible cases for pattern matching. Their use should be rare and explicitly justified.
*   **Good Example**:
    ```ocaml
    (* Standard variant is safer for library logic *)
    type event = Message of string | Disconnect
    ```
*   **Bad Example**:
    ```ocaml
    (* Core event type is extensible, which can be dangerous *)
    type event += Message of string
    ```

---

### 3. Expression-level and Idiomatic Patterns

#### [E120] Use `let _ = ...` for Intentionally Ignored Non-Unit Returns

*   **Description**: When calling a function that returns a non-`unit` value where the result is intentionally not used, explicitly ignore it with `let _ = ...`. Do not simply call it on its own line.
*   **Rationale**: The OCaml compiler issues a warning (warning 32) for ignored non-`unit` expressions because it's a common source of bugs. Using `let _ = ...` signals that the result is being discarded intentionally and safely silences the warning.
*   **Good Example**:
    ```ocaml
    let _ = List.map (fun x -> x * 2) [1; 2; 3]
    ```
*   **Bad Example**:
    ```ocaml
    List.map (fun x -> x * 2) [1; 2; 3]; (* This does nothing and will warn *)
    ```

#### [E125] Avoid Point-Free Style in Public Functions

*   **Description**: Avoid defining functions using a point-free style (i.e., without explicitly naming the arguments).
*   **Rationale**: While point-free style can be very concise (e.g., `let process = f |> g`), it often makes the code harder to read, debug, and understand, as the data being transformed is implicit. Explicitly naming the argument (e.g., `let process x = x |> f |> g`) is clearer.
*   **Good Example**:
    ```ocaml
    let process_user user =
      user |> find_profile |> normalize_name
    ```
*   **Bad Example**:
    ```ocaml
    let process_user = find_profile |> normalize_name
    ```
