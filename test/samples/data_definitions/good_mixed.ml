(* This file has both good (exempt) and bad (flagged) cases *)

(* Good: Simple list should be exempt *)
let supported_languages = [
  "ocaml";
  "reasonml"; 
  "javascript";
  "typescript";
  "python";
  "ruby";
  "rust";
  "go";
  "java";
  "csharp";
  "cpp";
  "c";
  "swift";
  "kotlin";
  "scala";
  "haskell";
  "elixir";
  "erlang";
  "clojure";
  "fsharp";
  "perl";
  "php";
  "lua";
  "r";
  "julia";
  "dart";
  "zig";
  "nim";
  "crystal";
  "vlang";
  "racket";
  "scheme";
  "lisp";
  "fortran";
  "cobol";
  "pascal";
  "ada";
  "prolog";
  "smalltalk";
  "objective-c";
  "assembly";
  "webassembly";
  "sql";
  "graphql";
  "solidity";
  "vyper";
  "move";
  "cairo";
  "motoko";
  "cadence";
  "clarity";
  "michelson";
  "plutus";
  "marlowe";
  "reach";
  "scilla";
  "ride";
  "teal";
  "yul";
  "fe";
  "sway";
  "ink";
]

(* Good: Short function is OK *)
let is_supported lang = List.mem lang supported_languages

(* Bad: Long complex value (not a simple list) should be flagged *)
let process_language lang =
  match lang with
  | "ocaml" -> "OCaml"
  | "reasonml" -> "ReasonML"
  | "javascript" -> "JavaScript"
  | "typescript" -> "TypeScript"
  | "python" -> "Python"
  | "ruby" -> "Ruby"
  | "rust" -> "Rust"
  | "go" -> "Go"
  | "java" -> "Java"
  | "csharp" -> "C#"
  | "cpp" -> "C++"
  | "c" -> "C"
  | "swift" -> "Swift"
  | "kotlin" -> "Kotlin"
  | "scala" -> "Scala"
  | "haskell" -> "Haskell"
  | "elixir" -> "Elixir"
  | "erlang" -> "Erlang"
  | "clojure" -> "Clojure"
  | "fsharp" -> "F#"
  | "perl" -> "Perl"
  | "php" -> "PHP"
  | "lua" -> "Lua"
  | "r" -> "R"
  | "julia" -> "Julia"
  | "dart" -> "Dart"
  | "zig" -> "Zig"
  | "nim" -> "Nim"
  | "crystal" -> "Crystal"
  | "vlang" -> "V"
  | "racket" -> "Racket"
  | "scheme" -> "Scheme"
  | "lisp" -> "Lisp"
  | "fortran" -> "Fortran"
  | "cobol" -> "COBOL"
  | "pascal" -> "Pascal"
  | "ada" -> "Ada"
  | "prolog" -> "Prolog"
  | "smalltalk" -> "Smalltalk"
  | "objective-c" -> "Objective-C"
  | "assembly" -> "Assembly"
  | "webassembly" -> "WebAssembly"
  | "sql" -> "SQL"
  | "graphql" -> "GraphQL"
  | "solidity" -> "Solidity"
  | "vyper" -> "Vyper"
  | "move" -> "Move"
  | "cairo" -> "Cairo"
  | "motoko" -> "Motoko"
  | "cadence" -> "Cadence"
  | "clarity" -> "Clarity"
  | "michelson" -> "Michelson"
  | _ -> "Unknown"