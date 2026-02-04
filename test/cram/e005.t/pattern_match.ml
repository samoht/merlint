(* This function has many match cases but should be allowed due to pattern matching allowance *)
let convert_token = function
  | `Plus -> "+"
  | `Minus -> "-"
  | `Times -> "*"
  | `Divide -> "/"
  | `Equal -> "="
  | `NotEqual -> "!="
  | `Less -> "<"
  | `Greater -> ">"
  | `LessEqual -> "<="
  | `GreaterEqual -> ">="
  | `And -> "&&"
  | `Or -> "||"
  | `Not -> "!"
  | `LeftParen -> "("
  | `RightParen -> ")"
  | `LeftBrace -> "{"
  | `RightBrace -> "}"
  | `LeftBracket -> "["
  | `RightBracket -> "]"
  | `Semicolon -> ";"
  | `Colon -> ":"
  | `Comma -> ","
  | `Dot -> "."
  | `Arrow -> "->"
  | `DoubleArrow -> "=>"
  | `Underscore -> "_"
  | `At -> "@"
  | `Hash -> "#"
  | `Dollar -> "$"
  | `Percent -> "%"
  | `Caret -> "^"
  | `Ampersand -> "&"
  | `Star -> "*"
  | `Question -> "?"
  | `Tilde -> "~"
  | `Backtick -> "`"
  | `Quote -> "'"
  | `DoubleQuote -> "\""
  | `Backslash -> "\\"
  | `Pipe -> "|"
  | `LeftShift -> "<<"
  | `RightShift -> ">>"
  | `PlusEqual -> "+="
  | `MinusEqual -> "-="
  | `TimesEqual -> "*="
  | `DivideEqual -> "/="
  | `ModEqual -> "%="
  | `AndEqual -> "&="
  | `OrEqual -> "|="
  | `XorEqual -> "^="
  | `LeftShiftEqual -> "<<="
  | `RightShiftEqual -> ">>="
  | `Increment -> "++"
  | `Decrement -> "--"
  | `TripleDot -> "..."
  | `DoubleColon -> "::"
  | `FatArrow -> "=>"
  | `ThinArrow -> "->"

(* This function should be reported as too long even with pattern matching *)
let process_with_pattern x =
  match x with
  | 0 -> 
      let a = 1 in
      let b = 2 in
      let c = 3 in
      let d = 4 in
      let e = 5 in
      let f = 6 in
      let g = 7 in
      let h = 8 in
      let i = 9 in
      let j = 10 in
      a + b + c + d + e + f + g + h + i + j
  | 1 ->
      let a = 11 in
      let b = 12 in
      let c = 13 in
      let d = 14 in
      let e = 15 in
      let f = 16 in
      let g = 17 in
      let h = 18 in
      let i = 19 in
      let j = 20 in
      a + b + c + d + e + f + g + h + i + j
  | 2 ->
      let a = 21 in
      let b = 22 in
      let c = 23 in
      let d = 24 in
      let e = 25 in
      let f = 26 in
      let g = 27 in
      let h = 28 in
      let i = 29 in
      let j = 30 in
      a + b + c + d + e + f + g + h + i + j
  | _ -> 0