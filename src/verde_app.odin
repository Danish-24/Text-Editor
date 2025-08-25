package verde

import "core:fmt"
import "core:time"
import "core:math"

//----------------------------------
// Application State
//----------------------------------

App_State :: struct {
  window      : Window_Handle,
  viewport    : [2]f32,

  gfx         : GFX_State,
  ui          : UI_Context,

  font        : Font_Atlas,

  frame_delta : f32,
}

app_init :: proc(ctx: ^App_State) -> bool {
  if !surface_init() {
    fmt.println("Failed to initialize windowing system")
    return false
  }

  ctx.window = surface_create(
    "verde", 640, 480
  )

  if ctx.window == nil { 
    fmt.println("Failed to create window");
    return false 
  }

  ctx.viewport = {640, 480}

  ok: bool
  ctx.gfx, ok = gfx_init(SURFACE_GL_PROC_ADDRESS)
  if !ok {
    fmt.eprintln("Failed to initialize graphics")
    return false
  }

  gfx_upload_proj(&ctx.gfx, ctx.viewport.x, ctx.viewport.y)

  ui_init(&ctx.ui)

  ctx.font, ok = font_atlas_create(&ctx.gfx, #load("jetbrains_mono.ttf"), font_height = 23)
  if !ok {
    fmt.println("fail")
  }
  font_atlas_preload_ascii(&ctx.gfx, &ctx.font)

  surface_setup_callbacks(
    ctx.window,
    resize_proc,
    ctx
  )

  return true
}

app_run :: proc(ctx: ^App_State) {
  time_now  := f32(0.0);
  time_last := f32(0.0);

  window := ctx.window
  gfx := &ctx.gfx
  ui := &ctx.ui

  for !surface_should_close(window) {
    free_all(context.temp_allocator)

    time_last = time_now
    time_now  = surface_get_seconds()
    ctx.frame_delta = time_now - time_last;

    gfx_clear(0)

    gfx_begin_frame(gfx, WHITE_TEXTURE)
    gfx_end_frame(gfx)


    gfx_begin_frame(gfx, 1)
    gfx_push_rect(gfx, 0, {f32(ctx.font.atlas_width), f32(ctx.font.atlas_height)}, color=hex_color(0xebdbc7))

    gfx_end_frame(gfx)

    surface_swap_buffer(ctx.window)
    surface_poll_events()
  }
}

resize_proc :: proc(x, y: i32, data: rawptr) {
  ctx := cast(^App_State) data
  ctx.viewport = {f32(x), f32(y)}
  gfx_resize_target(i32(ctx.viewport.x), i32(ctx.viewport.y))
  gfx_upload_proj(&ctx.gfx, ctx.viewport.x, ctx.viewport.y)
}
