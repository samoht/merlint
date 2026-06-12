let coerce x = Obj.magic x
let erased x = Obj.repr x
let recovered o : int = Obj.obj o
let tag_of x = Obj.tag (Obj.repr x)
