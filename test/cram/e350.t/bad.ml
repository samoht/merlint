let create_window visible resizable fullscreen =
  if visible && fullscreen && not resizable then
    "window"
  else "no window"
  
let w = create_window true false true