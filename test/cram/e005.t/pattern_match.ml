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

(* Match allowance should still apply when the match sits under [let open]. *)
let convert_opened_token token =
  let open Stdlib in
  match token with
  | `K00 -> "k00"
  | `K01 -> "k01"
  | `K02 -> "k02"
  | `K03 -> "k03"
  | `K04 -> "k04"
  | `K05 -> "k05"
  | `K06 -> "k06"
  | `K07 -> "k07"
  | `K08 -> "k08"
  | `K09 -> "k09"
  | `K10 -> "k10"
  | `K11 -> "k11"
  | `K12 -> "k12"
  | `K13 -> "k13"
  | `K14 -> "k14"
  | `K15 -> "k15"
  | `K16 -> "k16"
  | `K17 -> "k17"
  | `K18 -> "k18"
  | `K19 -> "k19"
  | `K20 -> "k20"
  | `K21 -> "k21"
  | `K22 -> "k22"
  | `K23 -> "k23"
  | `K24 -> "k24"
  | `K25 -> "k25"
  | `K26 -> "k26"
  | `K27 -> "k27"
  | `K28 -> "k28"
  | `K29 -> "k29"

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
