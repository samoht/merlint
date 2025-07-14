(* Local mutable state is fine *)
let compute_sum lst =
  let sum = ref 0 in
  List.iter (fun x -> sum := !sum + x) lst;
  !sum

(* Or better, use functional approach *)
let compute_sum lst = List.fold_left (+) 0 lst

(* Pass state explicitly *)
let incr_counter counter = counter + 1