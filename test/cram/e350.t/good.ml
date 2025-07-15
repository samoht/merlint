type visibility = Visible | Hidden
type window_mode = Windowed | Fullscreen
type resizable = Resizable | Fixed_size

let create_window ~visibility ~mode ~resizable =
  match visibility, mode, resizable with
  | Visible, Fullscreen, Fixed_size -> "window"
  | _ -> "no window"
  
let w = create_window ~visibility:Visible ~mode:Fullscreen ~resizable:Fixed_size