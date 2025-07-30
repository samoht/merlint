# Code Duplication Detection Rule Specification

## Overview

This rule should detect structurally similar code blocks that are candidates for extraction into shared functions. The goal is to identify code that has the same structure but may differ in variable names, literal values, or minor details.

## Algorithm: AST Subtree Hashing

This is the most robust and widely-used technique for finding structural duplicates with a very low false-positive rate.

### How It Works

1. **Parse to AST**: Convert the source code into an Abstract Syntax Tree (AST). This immediately discards irrelevant information like comments and whitespace.

2. **Normalize the Tree**: Traverse the AST and "normalize" certain nodes. This is the key step for detecting variations.
   - **Identifiers**: Replace all variable and function names with a generic placeholder. For example, `Pexp_ident "my_var"` becomes `Pexp_ident "_VAR_"`.
   - **Literals**: Replace all literal values (strings, numbers) with a placeholder. `Pexp_constant 42` becomes `Pexp_constant "_LIT_"`.

3. **Hash Subtrees**: Traverse the normalized tree. For each node, compute a hash that combines its own type with the hashes of its children. This means that any two subtrees that are structurally identical (after normalization) will produce the exact same hash.

4. **Match Hashes**: Store the hashes in a map. When a hash collision occurs, you've found a structural duplicate.

### Example

- Code A: `let total = price + 10`
- Code B: `let sum = cost + 25`

After parsing and normalization, both of these would effectively become the AST for:
```
let _VAR_ = _VAR_ + _LIT_
```

Since their normalized ASTs are identical, their hashes will match.

### Characteristics

- **False Positives**: Extremely low. A match from this algorithm means the code has the exact same syntactic structure. A developer looking at the two snippets will immediately agree they are duplicates and good candidates for a shared function.

- **Pros**:
  - Immune to changes in variable names, literals, comments, and whitespace
  - Understands code structure, making it very accurate
  - The "normalization" step is configurable, allowing you to tune how sensitive it is

- **Cons**:
  - More computationally intensive than token-based methods (requires a full parse)
  - Will not detect reordered statements (a Type 3 variation)

## Implementation Plan

### Step 1: Parse the Code (Already Done)
We already have the logic to parse a file into a Ppxlib.structure.

```ocaml
let structure = Ppxlib.Parse.implementation lexbuf
```

### Step 2: Normalize the AST
Create a visitor that replaces variable names and literals.

```ocaml
open Ppxlib

(* A visitor that replaces identifiers and constants with placeholders *)
let normalizer =
  object
    inherit Ast_traverse.map as super

    (* Normalize variable names *)
    method! expression expr =
      match expr.pexp_desc with
      | Pexp_ident _ -> 
          { expr with pexp_desc = Pexp_ident (Located.mk (Lident "_VAR_")) }
      | _ -> super#expression expr

    (* Normalize literals *)
    method! constant _ =
      Ast_builder.Default.pconst_integer "_LIT_" None
  end

let normalized_structure = normalizer#structure structure
```

### Step 3: Hash the Normalized Subtrees
Create another visitor that traverses the normalized_structure and computes a hash for each node.

```ocaml
let hashes = Hashtbl.create 1024

let hasher =
  object
    inherit Ast_traverse.iter as super

    method! expression expr =
      (* Compute a hash for the current expression node.
         A simple hash could combine the node type with its 
         children's hashes.
         This part requires a more sophisticated hashing strategy. *)
      let node_hash = (* ... compute hash of expr ... *) in

      (* Store the hash and its location *)
      let existing = Hashtbl.find_opt hashes node_hash in
      Hashtbl.replace hashes node_hash (expr.pexp_loc :: existing);

      super#expression expr
  end

let () = hasher#structure normalized_structure
```

### Step 4: Report Duplicates
Finally, iterate through your hashes table. Any entry with more than one location is a code duplicate.

## Configuration Options

1. **Minimum Size**: To avoid flagging trivial duplicates (like `x + 1`), only consider subtrees with a minimum number of nodes or a certain depth.

2. **Normalization Level**: Configure what gets normalized:
   - Variable names only
   - Literals only
   - Both variables and literals
   - Type annotations
   - Module names

3. **Scope**: Configure where to look for duplicates:
   - Within a single file
   - Across files in the same directory
   - Across the entire project

## Example Output

```
[E700] Code Duplication
Found 2 structurally identical code blocks:

lib/user.ml:45-48:
  let calculate_total price tax =
    let subtotal = price * quantity in
    let total = subtotal + tax in
    total

lib/order.ml:123-126:
  let compute_amount cost fee =
    let base = cost * count in
    let amount = base + fee in
    amount

Consider extracting into a shared function:
  let calculate_with_addition base multiplier addition =
    let subtotal = base * multiplier in
    let total = subtotal + addition in
    total
```

## Alternative Algorithm: Suffix Tree on Token Stream

For reference, here's the alternative token-based approach:

1. **Lex & Normalize**: Convert the code into a normalized token stream.
2. **Build a Suffix Tree**: Build a generalized suffix tree from the token streams of all files.
3. **Find Common Substrings**: Find the longest common substrings within this tree.

**Pros**: Can be faster than AST-based methods for very large codebases.
**Cons**: Doesn't understand code structure and is sensitive to statement reordering.

## Recommendation

For a tool that needs to be both accurate and useful for refactoring, the AST Subtree Hashing algorithm is the state-of-the-art and the best choice. It provides actionable results that directly point to code that can be refactored into a single, parameterized function.