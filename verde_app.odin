package verde

import SDL "vendor:sdl3"
import "core:fmt"

WINDOW_WIDTH  :: 1024
WINDOW_HEIGHT :: 768

Window_Handle :: ^SDL.Window

App_State :: struct {
  // Core systems
  window:  Window_Handle,
  gfx:     GFX_Context,

  running: bool,
}

app_init :: proc(ctx: ^App_State) -> bool {
  if !sdl_init(ctx) do return false
  if !graphics_init(ctx) do return false

  //editor_init(&ctx.editor)

  ctx.running = true
  return true
}

sdl_init :: proc(ctx: ^App_State) -> bool {
  if !SDL.Init({.VIDEO}) {
    fmt.eprintln("Failed to initialize SDL")
    return false
  }

  SDL.GL_SetAttribute(SDL.GL_CONTEXT_MAJOR_VERSION, GL_VERSION_MAJOR)
  SDL.GL_SetAttribute(SDL.GL_CONTEXT_MINOR_VERSION, GL_VERSION_MINOR)
  SDL.GL_SetAttribute(SDL.GL_CONTEXT_PROFILE_MASK, i32(SDL.GLProfile.CORE))
  SDL.GL_SetAttribute(SDL.GL_DOUBLEBUFFER, 1)

  ctx.window = SDL.CreateWindow(
    "verde",
    WINDOW_WIDTH, WINDOW_HEIGHT,
    {.RESIZABLE, .OPENGL}
  )

  if ctx.window == nil {
    fmt.eprintln("Failed to create window:", SDL.GetError())
    return false
  }

  return true
}

graphics_init :: proc(ctx: ^App_State) -> bool {
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

  SDL.GL_SetSwapInterval(1)
  return true
}

app_run :: proc(ctx: ^App_State) {
  for ctx.running {
    if handle_events(ctx) { break }
  }
}

handle_events :: proc(ctx: ^App_State) -> (exit : bool){
  event: SDL.Event

  for SDL.PollEvent(&event) {
    #partial switch event.type {
    case .QUIT:
      ctx.running = false
      return true
    }
  }
  return false
}

app_cleanup :: proc(ctx: ^App_State) {
  if ctx.window != nil {
    SDL.DestroyWindow(ctx.window)
  }

  SDL.Quit()
}

render :: proc(ctx: ^App_State) {
  gfx_clear()

  SDL.GL_SwapWindow(ctx.window)
}
