let step1 x y = (x + 1, y + 1)
let step2 (a, b) = (a * 2, b * 2)
let combine (c, d) = (c + d) * 2

let process_all x y =
  let (a, b) = step1 x y in
  let (c, d) = step2 (a, b) in
  combine (c, d)

(* Functions with large pattern matches get 2 lines per case + 10% allowance *)
type property =
  | Color | Background_color | Border_color | Outline_color | Border_top_color
  | Border_right_color | Border_bottom_color | Border_left_color | Text_color

let with_context f = f ()

(* Test the pattern: fun xxx -> fun () -> match ... *)
let read_value prop =
  with_context @@ fun () ->
  match prop with
  | Color ->
      let x = 1 in
      let y = 2 in
      x + y
  | Background_color ->
      let x = 3 in
      let y = 4 in
      x + y
  | Border_color ->
      let x = 5 in
      let y = 6 in
      x + y
  | Outline_color ->
      let x = 7 in
      let y = 8 in
      x + y
  | Border_top_color ->
      let x = 9 in
      let y = 10 in
      x + y
  | Border_right_color ->
      let x = 11 in
      let y = 12 in
      x + y
  | Border_bottom_color ->
      let x = 13 in
      let y = 14 in
      x + y
  | Border_left_color ->
      let x = 15 in
      let y = 16 in
      x + y
  | Text_color ->
      let x = 17 in
      let y = 18 in
      x + y