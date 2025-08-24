package verde

MAX_ELEMENTS :: 1024

UI_Box :: struct {
  parent : u32,
  next : u32,
  child : u32,
}

UI_Context :: struct {
  flat_array : [^]UI_Box,
  
  pointer : struct {
    x, y : f32,
    pressed, down, up : bool,
  }
}

ui_init :: proc(ctx: ^UI_Context) {
  ctx.flat_array = make([^]UI_Box, MAX_ELEMENTS, context.allocator)
}

ui_set_pointer :: proc(ctx: ^UI_Context, x, y: f32, pressed, down, up: bool) {
  ctx.pointer = {
    x, y, pressed, down, up
  }
}

pointer_pos :: proc(ctx: ^UI_Context) -> (x: f32, y: f32) {
  return ctx.pointer.x, ctx.pointer.y
}

pointer_click :: proc(ctx: ^UI_Context) -> bool {
  return ctx.pointer.down
}

pointer_release :: proc(ctx: ^UI_Context) -> bool {
  return ctx.pointer.up
}


