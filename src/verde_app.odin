package verde

import "core:fmt"
import "core:time"
import "base:runtime"
import "core:math"

import "core:strings"

import "vendor:glfw"

Window_Handle :: glfw.WindowHandle

App_Context :: struct {
  window      : Window_Handle,
  input       : Input_State,
  viewport    : [2]f32,
  gfx         : GFX_State,
  layout      : Layout_State,
  font        : Font_Atlas,
  frame_delta : f32,
  panes       : Pane_Tree,
}

WIDTH  :: 640
HEIGHT :: 640

app_init :: proc(ctx: ^App_Context) -> bool {
  ////////////////////////////
  // ~geb: Windowing

	if !glfw.Init() {
		fmt.eprintln("Failed to initialize GLFW")
		return false
	}

	glfw.WindowHint(glfw.RESIZABLE, true)
	glfw.WindowHint(glfw.MAXIMIZED, false)
	glfw.WindowHint(glfw.DECORATED, true)

	ctx.window = glfw.CreateWindow(WIDTH, HEIGHT, "verde", nil, nil)
	if ctx.window == nil {
		fmt.eprintln("Failed to create window")
		return false
  }

  glfw.MakeContextCurrent(ctx.window)
  glfw.SwapInterval(0)

  glfw.SetWindowUserPointer(ctx.window, ctx)

  glfw.SetFramebufferSizeCallback(ctx.window, proc "c" (window: Window_Handle, width, height: i32) {
    context = runtime.default_context()
    ctx := cast(^App_Context) glfw.GetWindowUserPointer(window)
    gfx_resize_target(&ctx.gfx, width, height)
    ctx.viewport = {f32(width), f32(height)}
  })

  glfw.SetCharCallback(ctx.window, proc "c" (window: Window_Handle, codepoint: rune) {
    context = runtime.default_context()
    ctx := cast(^App_Context) glfw.GetWindowUserPointer(window)
    ctx.input.char_stream = codepoint
    ctx.input.had_char_input = true
  })

  glfw.SetKeyCallback(ctx.window, proc "c" (window: Window_Handle, key, scancode, action, mods: i32) {
    context = runtime.default_context()
    ctx := cast(^App_Context) glfw.GetWindowUserPointer(window)
    keycode := _get_keycode_from_platform(key)

    switch action {
    case glfw.PRESS:
      ctx.input.keys_current += {keycode}
    case glfw.REPEAT:
      ctx.input.keys_repeat += {keycode}
    case glfw.RELEASE:
      ctx.input.keys_current -= {keycode}
    }
  })

  glfw.SetMouseButtonCallback(ctx.window, proc "c" (window: Window_Handle, button, action, mods: i32) {
    context = runtime.default_context()
    ctx := cast(^App_Context) glfw.GetWindowUserPointer(window)
    mouse_code := Mouse_Code(button)

    switch action {
    case glfw.PRESS:
      ctx.input.mouse_current += {mouse_code}
    case glfw.RELEASE:
      ctx.input.mouse_current -= {mouse_code}
    }
  })

  glfw.SetCursorPosCallback(ctx.window, proc "c" (window: Window_Handle, x, y: f64) {
    context = runtime.default_context()
    ctx := cast(^App_Context) glfw.GetWindowUserPointer(window)
    ctx.input.pointer_current = {f32(x), f32(y)}
  })

  glfw.SetScrollCallback(ctx.window, proc "c" (window: Window_Handle, x, y: f64) {
    context = runtime.default_context()
    ctx := cast(^App_Context) glfw.GetWindowUserPointer(window)
    ctx.input.scroll = {f32(x), f32(y)}
  })

  ////////////////////////////
  // ~geb: GFX systems

  ok: bool
  ctx.gfx, ok = gfx_init(glfw.gl_set_proc_address)
  if !ok {
    fmt.eprintln("Failed to initialize GFX")
    return false
  }

  ctx.viewport = {WIDTH, HEIGHT}
  gfx_resize_target(&ctx.gfx, i32(ctx.viewport.x), i32(ctx.viewport.y))

  ctx.font, ok = font_atlas_create(&ctx.gfx, #load("fonts/jetbrains_mono.ttf"), font_height = 22)
  if !ok {
    fmt.eprintln("Failed to create font atlas")
    return false
  }
  font_atlas_preload_ascii(&ctx.gfx, &ctx.font)

  ////////////////////////////
  // ~geb: UI

  layout_init(&ctx.layout)
  layout_set_context(&ctx.layout)
  ctx.panes = pane_tree_create()
  pane_tree_split(&ctx.panes)

  return true
}

app_run :: proc(ctx: ^App_Context) {
  time_now: f32 = 0.0
  time_last: f32 = 0.0

  for !glfw.WindowShouldClose(ctx.window) {
    time_last = time_now
    time_now = cast(f32) glfw.GetTime()
    ctx.frame_delta = time_now - time_last

    free_all(context.temp_allocator)
    _poll_input(ctx)

    if is_key_down(ctx, .Left_Control) {
      if on_key_down(ctx, .Enter) {
        pane_tree_split(&ctx.panes, horizontal = is_key_down(ctx, .Left_Shift))
      }
      if on_key_down(ctx, .Backspace){
        pane_tree_collapse(&ctx.panes)
      }

      if on_key_down(ctx, .L) {
        pane_tree_focus_move(&ctx.panes, .Right)
      } 
      if on_key_down(ctx, .K) {
        pane_tree_focus_move(&ctx.panes, .Up)
      }
      if on_key_down(ctx, .J) {
        pane_tree_focus_move(&ctx.panes, .Down)
      }
      if on_key_down(ctx, .H) {
        pane_tree_focus_move(&ctx.panes, .Left)
      }
    }

    _render_frame(ctx)

    glfw.SwapBuffers(ctx.window)
  }
}

_render_frame :: proc(ctx: ^App_Context) {
  @(static) smooth_cursor : vec2_f32
  cursor_pos := get_pointer(ctx)
  cursor_delta := get_pointer_delta(ctx)

  smooth_cursor = smooth_damp(smooth_cursor, cursor_pos, 0.2, ctx.frame_delta)


  layout_begin(ctx.viewport.x, ctx.viewport.y)
  layout_panes_recursive(&ctx.panes, ROOT_PANE_HANDLE)
  panels := layout_end()

  gfx_clear(0)
  gfx_begin_frame(&ctx.gfx)
  defer gfx_end_frame(&ctx.gfx)

  draw_panels(&ctx.gfx, &ctx.font, panels)
}

_poll_input :: proc(ctx: ^App_Context) {
  using ctx.input

  keys_prev = keys_current
  keys_repeat = {}
  mouse_prev = mouse_current
  pointer_prev = pointer_current

  scroll = {}
  had_char_input = false

  glfw.PollEvents()
}
