let step1 x y = (x + 1, y + 1)
let step2 (a, b) = (a * 2, b * 2)
let combine (c, d) = (c + d) * 2

let process_all x y =
  let (a, b) = step1 x y in
  let (c, d) = step2 (a, b) in
  combine (c, d)