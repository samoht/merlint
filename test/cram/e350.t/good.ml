type visibility = Visible | Hidden
type window_mode = Windowed | Fullscreen
type resizable = Resizable | Fixed_size

let create_window ~visibility ~mode ~resizable =
  ...
  
let w = create_window ~visibility:Visible ~mode:Fullscreen ~resizable:Fixed_size