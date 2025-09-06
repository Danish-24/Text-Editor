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
}

app_init :: proc(ctx: ^App_Context) -> bool {
	if !glfw.Init() {
		fmt.eprintln("Failed to initialize GLFW")
		return false
	}

	glfw.WindowHint(glfw.RESIZABLE, true)
	glfw.WindowHint(glfw.MAXIMIZED, false)
	glfw.WindowHint(glfw.DECORATED, true)


	ctx.window = glfw.CreateWindow(640, 480, "verde", nil, nil)
	if ctx.window == nil {
		fmt.eprintln("Failed to create window")
		return false
	}
	
	glfw.MakeContextCurrent(ctx.window)
	glfw.SwapInterval(0)
	ctx.viewport = {640, 480}

	ok: bool
	ctx.gfx, ok = gfx_init(glfw.gl_set_proc_address)
	if !ok {
		fmt.eprintln("Failed to initialize GFX")
		return false
	}


	gfx_resize_target(&ctx.gfx, i32(ctx.viewport.x), i32(ctx.viewport.y))

	ctx.font, ok = font_atlas_create(&ctx.gfx, #load("fonts/jetbrains_mono.ttf"), font_height = 24)
	if !ok {
		fmt.eprintln("Failed to create font atlas")
		return false
	}
	font_atlas_preload_ascii(&ctx.gfx, &ctx.font)

	_setup_callbacks(ctx)

  layout_init(&ctx.layout)
  layout_set_context(&ctx.layout)

	return true
}

_setup_callbacks :: proc(ctx: ^App_Context) {
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
}

app_run :: proc(ctx: ^App_Context) {
	time_now: f32 = 0.0
	time_last: f32 = 0.0

	for !glfw.WindowShouldClose(ctx.window) {
		free_all(context.temp_allocator)
		_poll_input(ctx)

		time_last = time_now
		time_now = cast(f32) glfw.GetTime()
		ctx.frame_delta = time_now - time_last

		_handle_input(ctx)

		_render_frame(ctx)
		
		glfw.SwapBuffers(ctx.window)
	}
}

_handle_input :: proc(ctx: ^App_Context) {
	if is_key_down(ctx, .W) {
		gfx_wireframe(true)
	} else {
		gfx_wireframe(false)
	}

	height := font_atlas_height(&ctx.font)
	if on_key_repeat(ctx, .Equal) && height < 128 && is_key_down(ctx, .Left_Control) {
		font_atlas_resize_glyphs(&ctx.gfx, &ctx.font, height + 2)
	} else if on_key_repeat(ctx, .Minus) && height > 4 && is_key_down(ctx, .Left_Control) {
		font_atlas_resize_glyphs(&ctx.gfx, &ctx.font, height - 2)
	}
}

cursor_pos: vec2_i32 = 0
_render_frame :: proc(ctx: ^App_Context) {

  layout_begin(ctx.viewport.x, ctx.viewport.y, direction=.Horizontal)

  if on_key_repeat(ctx, .J) { cursor_pos.y += 1}
  if on_key_repeat(ctx, .K) { cursor_pos.y -= 1}

  if on_key_repeat(ctx, .U) && is_key_down(ctx, .Left_Control) { cursor_pos.y -= 6}
  if on_key_repeat(ctx, .D) && is_key_down(ctx, .Left_Control) { cursor_pos.y += 6}

  if on_key_repeat(ctx, .H) { cursor_pos.x -= 1}
  if on_key_repeat(ctx, .L) { cursor_pos.x += 1}

	gfx_clear(hex_color(0x131313))

	gfx_begin_frame(&ctx.gfx)
	defer gfx_end_frame(&ctx.gfx)

  {
    height := font_atlas_height(&ctx.font)

    width := height / 2.2
    f_cursor_pos := vec2_f32{f32(cursor_pos.x) * width, f32(cursor_pos.y)*height}
    @(static) c_pos := vec2_f32 {}
    c_pos = smooth_damp(c_pos, f_cursor_pos, 0.05, ctx.frame_delta)

    gfx_push_rect_rounded(
      &ctx.gfx,
      c_pos,
      {width, height},
      color=hex_color(0x99856a),
      radii=width/2,
    )
    gfx_push_text(
      &ctx.gfx,
      #load("verde_layout.odin"),
      &ctx.font,
      color=hex_color(0x99856A),
      monospace_advance=width
    )
    /*
    gfx_push_rect(
      &ctx.gfx,
      0,
      {auto_cast ctx.font.atlas_width,auto_cast ctx.font.atlas_height},
      tex_id=ctx.font.texture_id,
      color=hex_color(0x99856a),
    ) 
    */
  }

	gfx_end_frame(&ctx.gfx)
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
