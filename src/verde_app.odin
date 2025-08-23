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

hit_test_callback :: proc "c" (window: ^SDL.Window, area: ^SDL.Point, data: rawptr) -> SDL.HitTestResult {
  ctx := cast(^App_State)data
  
  w, h: i32
  SDL.GetWindowSize(window, &w, &h)
  
  x := area.x
  y := area.y
  
  title_bar_height :: 32  // Height of draggable title bar area
  border_size :: 6        // Size of resize borders
  
  // Resize borders (if you want resize functionality)
  if x < border_size && y < border_size {
    return .RESIZE_TOPLEFT
  }
  if x > w - border_size && y < border_size {
    return .RESIZE_TOPRIGHT
  }
  if x < border_size && y > h - border_size {
    return .RESIZE_BOTTOMLEFT
  }
  if x > w - border_size && y > h - border_size {
    return .RESIZE_BOTTOMRIGHT
  }
  if x < border_size {
    return .RESIZE_LEFT
  }
  if x > w - border_size {
    return .RESIZE_RIGHT
  }
  if y < border_size {
    return .RESIZE_TOP
  }
  if y > h - border_size {
    return .RESIZE_BOTTOM
  }
  
  // Title bar area (draggable)
  if y <= title_bar_height {
    return .DRAGGABLE
  }
  
  // Client area (normal interaction)
  return .NORMAL
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
    { .RESIZABLE, .OPENGL, .TRANSPARENT, .BORDERLESS }
  )
  
  if ctx.window == nil {
    fmt.eprintln("Failed to create window:", SDL.GetError())
    return false
  }
  
  // Set up custom hit testing
  if !SDL.SetWindowHitTest(ctx.window, hit_test_callback, ctx) {
    fmt.eprintln("Failed to set hit test callback:", SDL.GetError())
    // Not critical, continue anyway
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
  ctx.running = true
  return true
}

app_run :: proc(ctx: ^App_State) {
  event: SDL.Event
  
  handle_event :: #force_inline proc(ctx: ^App_State, event: SDL.Event) {
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
    }
  }
  
  time_now := SDL.GetPerformanceCounter()
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
    
    gfx_clear({0, 0, 0, 0})
    gfx_begin_frame(gfx)
    
    gfx_push_rect_rounded(gfx, 0, ctx.viewport, radii = 10, color = {0.4, 0.4, 0.4, 1.0})
    gfx_push_rect_rounded(gfx, 1, ctx.viewport-2, radii = 9, color = {0.1, 0.1, 0.1, 1.0})
    gfx_push_rect_rounded(gfx, 0, {ctx.viewport.x, 32}, radii = {10,10,0,0}, color = {0.4, 0.4, 0.4, 1.0})
    
    gfx_end_frame(gfx)
    SDL.GL_SwapWindow(ctx.window)
  }
  
  SDL.DestroyWindow(ctx.window)
  SDL.Quit()
}
