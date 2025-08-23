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
    { .RESIZABLE, .OPENGL }
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

  gfx := &ctx.gfx

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
    gfx_begin_frame(gfx)
    gfx_upload_proj(gfx, ctx.viewport.x, ctx.viewport.y)

    gfx_push_rect(
      gfx,
      pos = {0,0}, 
      size = {200,200},
      color = [4]f32{54, 106, 143, 255}/255
    )

    gfx_end_frame(gfx)
    SDL.GL_SwapWindow(ctx.window)
  }

  SDL.DestroyWindow(ctx.window)
  SDL.Quit()
}
