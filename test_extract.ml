let extract_location_from_parsetree text =
  let location_regex = Re.compile (Re.seq [
    Re.str "(";
    Re.group (Re.rep1 (Re.compl [Re.char '[']));
    Re.str "[";
    Re.group (Re.rep1 Re.digit);
    Re.str ",";
    Re.rep Re.digit;
    Re.str "+";
    Re.group (Re.rep1 Re.digit);
    Re.str "]";
  ]) in
  try
    let substrings = Re.exec location_regex text in
    let line = int_of_string (Re.Group.get substrings 2) in
    let col = int_of_string (Re.Group.get substrings 3) in
    Some (line, col)
  with _ -> None

let () = 
  let text = "Pexp_ident \"Obj.magic\" (bad_style.ml[2,27+16]..[2,27+25])" in
  match extract_location_from_parsetree text with
  | Some (line, col) -> Printf.printf "Found location: line=%d, col=%d\n" line col
  | None -> Printf.printf "No location found\n"
EOF < /dev/null