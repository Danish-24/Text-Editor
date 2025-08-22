package verde


import "core:fmt"
import "core:time"

import SDL "vendor:sdl3"

Window_Handle :: ^SDL.Window

App_State :: struct {
	window: Window_Handle,
	viewport: [2]f32,

  frame_delta : f32,
	gfx: GFX_State,

	running: bool,
}

hit_test_callback :: proc "c" (win: ^SDL.Window, area: ^SDL.Point, data: rawptr) -> SDL.HitTestResult {
  ctx := cast(^App_State)data

  x := f32(area.x)
  y := f32(area.y)

  // Define resize border thickness
  border :f32= 8.0

  w, h : i32
  w = auto_cast ctx.viewport.x
  h = auto_cast ctx.viewport.y

  fw := f32(w)
  fh := f32(h)

  if x <= border && y <= border {
    return .RESIZE_TOPLEFT
  }
  if x >= fw - border && y <= border {
    return .RESIZE_TOPRIGHT
  }
  if x <= border && y >= fh - border {
    return .RESIZE_BOTTOMLEFT
  }
  if x >= fw - border && y >= fh - border {
    return .RESIZE_BOTTOMRIGHT
  }

  if y <= border {
    return .RESIZE_TOP
  }
  if y >= fh - border {
    return .RESIZE_BOTTOM
  }
  if x <= border {
    return .RESIZE_LEFT
  }
  if x >= fw - border {
    return .RESIZE_RIGHT
  }
  if y >= 0 && y < 32 {
    return .DRAGGABLE
  }

  return .NORMAL
}


render_titlebar :: proc(ctx: ^App_State) {
  titlebar_color := [4]f32{0.2, 0.2, 0.2, 1.0}
  gfx_push_rect(&ctx.gfx, {0, 0}, {ctx.viewport.x, 32}, titlebar_color)
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

  ctx.window = SDL.CreateWindow(
    "verde",
    640, 480,
    {.RESIZABLE, .OPENGL, .BORDERLESS}
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

  SDL.GL_SetSwapInterval(0)

  SDL.SetWindowHitTest(ctx.window, hit_test_callback, rawptr(ctx))

  ctx.running = true
  return true
}

app_run :: proc(ctx: ^App_State) {
  event: SDL.Event

  handle_event :: proc(ctx: ^App_State, event: SDL.Event) {
    #partial switch event.type {
    case .WINDOW_RESIZED:
      w := event.window.data1
      h := event.window.data2
      ctx.viewport = {f32(w), f32(h)}
      gfx_resize_target(w, h)
    }
  }

  time_now := SDL.GetPerformanceCounter();
  time_last := u64(0)

  main_loop: for ctx.running {
    time_last = time_now
    time_now = SDL.GetPerformanceCounter()
    ctx.frame_delta = f32(f64(time_now - time_last) / f64(SDL.GetPerformanceFrequency()))

    for SDL.PollEvent(&event) {
      if event.type == .QUIT {
        ctx.running = false
        break main_loop
      } else {
        handle_event(ctx, event)
      }
    }

    gfx_clear({0,0,0,1})
    gfx_begin_frame(&ctx.gfx)
    gfx_upload_proj(&ctx.gfx, ctx.viewport.x, ctx.viewport.y)

    // Render titlebar
    render_titlebar(ctx)

    gfx_end_frame(&ctx.gfx)
    SDL.GL_SwapWindow(ctx.window)
  }

  SDL.DestroyWindow(ctx.window)
  SDL.Quit()
}
