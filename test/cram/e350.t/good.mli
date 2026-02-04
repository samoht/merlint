type visibility = Visible | Hidden
type window_mode = Windowed | Fullscreen
type resizable = Resizable | Fixed_size

val create_window : visibility:visibility -> mode:window_mode -> resizable:resizable -> string