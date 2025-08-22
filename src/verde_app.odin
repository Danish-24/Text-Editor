package verde

import "core:fmt"

import SDL "vendor:sdl3"

Window_Handle :: ^SDL.Window

App_State :: struct {
	window : Window_Handle,
	gfx : GFX_State,
	running : bool,
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
    {.RESIZABLE, .OPENGL}
  )

  if ctx.window == nil {
    fmt.eprintln("Failed to create window:", SDL.GetError())
    return false
  }

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
	ctx.running = true
	return true
}

app_run :: proc(ctx: ^App_State) {
	event : SDL.Event
	
	main_loop : for ctx.running {
    for SDL.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT: 
				ctx.running = false
				break main_loop
			}
		}
    gfx_clear()

		SDL.GL_SwapWindow(ctx.window)
  }

	SDL.DestroyWindow(ctx.window)
	SDL.Quit();
}
