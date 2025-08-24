package verde

import "core:fmt"
import "core:time"
import "core:math"

import SDL "vendor:sdl3"

//----------------------------------
// Window + Cursor State
//----------------------------------

Window_Handle :: ^SDL.Window

Cursor_Pointer :: struct {
  x, y        : f32,
  dx, dy      : f32,
  pressed     : b8,
  just_down   : b8,
  just_released : b8,
  double_click : b8,
}

//----------------------------------
// Application State
//----------------------------------

App_State :: struct {
  window      : Window_Handle,
  viewport    : [2]f32,

  gfx         : GFX_State,
  ui          : UI_Context,

  cursor      : Cursor_Pointer,
  font        : Font_Atlas,

  frame_delta : f32,
  running     : bool,
}

app_init :: proc(ctx: ^App_State) -> bool {
  if !SDL.Init({.VIDEO}) {
    fmt.eprintln("Failed to initialize SDL")
    return false
  }

  SDL.GL_SetAttribute(SDL.GL_CONTEXT_MAJOR_VERSION, 3)
  SDL.GL_SetAttribute(SDL.GL_CONTEXT_MINOR_VERSION, 3)
  SDL.GL_SetAttribute(SDL.GL_CONTEXT_PROFILE_MASK, i32(SDL.GLProfile.CORE))
  SDL.GL_SetAttribute(SDL.GL_DOUBLEBUFFER, 1)
  SDL.GL_SetAttribute(SDL.GL_MULTISAMPLEBUFFERS, 1)
  SDL.GL_SetAttribute(SDL.GL_MULTISAMPLESAMPLES, 4)

  ctx.window = SDL.CreateWindow(
    "verde",
    640, 480,
    { .RESIZABLE, .OPENGL },
  )

  if ctx.window == nil {
    fmt.eprintln("Failed to create window:", SDL.GetError())
    return false
  }

  ctx.viewport = {640, 480}

  gl_context := SDL.GL_CreateContext(ctx.window)
  if gl_context == nil {
    fmt.eprintln("Failed to create OpenGL context:", SDL.GetError())
    return false
  }

  ok: bool
  ctx.gfx, ok = gfx_init(SDL.gl_set_proc_address)
  if !ok {
    fmt.eprintln("Failed to initialize graphics")
    return false
  }

  gfx_upload_proj(&ctx.gfx, ctx.viewport.x, ctx.viewport.y)

  SDL.GL_SetSwapInterval(0)
  SDL.SetWindowMinimumSize(ctx.window, 280, 51)

  ui_init(&ctx.ui)

  ctx.font, ok = font_atlas_create(&ctx.gfx, #load("jetbrains_mono.ttf"), font_height = 23)
  if !ok {
    fmt.println("fail")
  }
  font_atlas_preload_ascii(&ctx.gfx, &ctx.font)

  ctx.running = true
  return true
}

handle_event :: proc(ctx: ^App_State, event: SDL.Event) {
  #partial switch event.type {
  case .WINDOW_RESIZED:
    w := event.window.data1
    h := event.window.data2
    ctx.viewport = {f32(w), f32(h)}
    gfx_resize_target(w, h)
    gfx_upload_proj(&ctx.gfx, ctx.viewport.x, ctx.viewport.y)
    SDL.GL_SwapWindow(ctx.window)

  case .KEY_DOWN:
    if event.key.key == SDL.K_P {
      @(static) wireframe := false
      wireframe = !wireframe
      gfx_wireframe(wireframe)
    }

  case .MOUSE_MOTION:
    ctx.cursor.x  = event.motion.x
    ctx.cursor.y  = event.motion.y
    ctx.cursor.dx = event.motion.xrel
    ctx.cursor.dy = event.motion.yrel

  case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
    down := b8(event.button.down)
    ctx.cursor.double_click  = event.button.clicks == 2
    ctx.cursor.just_down     = down
    ctx.cursor.just_released = !down
    ctx.cursor.pressed       = down
  }
}

app_run :: proc(ctx: ^App_State) {
  event: SDL.Event

  time_now  := SDL.GetPerformanceCounter()
  time_last := u64(0)
  time_accum := f32(0.0)

  gfx := &ctx.gfx
  ui := &ctx.ui


  main_loop: for ctx.running {
    // Frame timing
    time_last = time_now
    time_now  = SDL.GetPerformanceCounter()
    ctx.frame_delta = f32(f64(time_now - time_last) / f64(SDL.GetPerformanceFrequency()))
    time_accum += ctx.frame_delta

    // Poll events
    for SDL.PollEvent(&event) {
      if event.type == .QUIT {
        ctx.running = false
        break main_loop
      }
      handle_event(ctx, event)
    }

    ui_set_pointer(
      ui,
      ctx.cursor.x, ctx.cursor.y, 
      auto_cast ctx.cursor.pressed, 
      auto_cast ctx.cursor.just_down, 
      auto_cast ctx.cursor.just_released
    )

    gfx_clear(0)

    gfx_begin_frame(gfx, WHITE_TEXTURE)
    gfx_end_frame(gfx)


    gfx_begin_frame(gfx, 1)
    gfx_push_rect(gfx, 0, 512, color=hex_color(0xebdbc7))
    gfx_end_frame(gfx)

    SDL.GL_SwapWindow(ctx.window)

    ctx.cursor.just_released = false
    ctx.cursor.just_down     = false

    free_all(context.temp_allocator)
  }

  SDL.DestroyWindow(ctx.window)
  SDL.Quit()
}
