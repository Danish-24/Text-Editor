package verde

import "base:runtime"

import "vendor:glfw"

GL_SetProcAddress :: #type proc(p: rawptr, name: cstring)
Resize_Proc :: #type proc(x, y: i32, data: rawptr)

Window_Flags :: bit_set[Window_Flag; u32]
Window_Flag :: enum {
  Maximized,
  Resizable,
  Decorated,
}

Window_Handle :: rawptr

surface_init :: proc() -> bool{
  return bool(glfw.Init())
}

surface_poll_events :: proc() {
  glfw.PollEvents()
}

surface_create :: proc(title : cstring, w, h : i32, flags : Window_Flags = {.Resizable, .Decorated}) -> Window_Handle {
  glfw.WindowHint(glfw.RESIZABLE, .Resizable in flags)
  glfw.WindowHint(glfw.MAXIMIZED, .Maximized in flags)
  glfw.WindowHint(glfw.DECORATED, .Decorated in flags)

  window := glfw.CreateWindow(w, h, title, nil, nil)
  if window == nil { return nil }

  glfw.MakeContextCurrent(window)
  glfw.SwapInterval(0)

  return window
} 

surface_should_close :: proc(window: Window_Handle) -> bool {
  return cast(bool) glfw.WindowShouldClose(auto_cast window)
}

surface_swap_buffer :: proc(window: Window_Handle) {
  glfw.SwapBuffers(auto_cast window)
}

Callback_Data :: struct {
  resize_proc : Resize_Proc,
  user_data: rawptr,
}

@(private) g_callback_data: Callback_Data
@(private) _glfw_framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
  context = runtime.default_context()
  if g_callback_data.resize_proc != nil {
    g_callback_data.resize_proc(width, height, g_callback_data.user_data)
  }
}

surface_setup_callbacks :: proc(
  window: Window_Handle,
  resize_proc: proc(x, y: i32, data: rawptr),
  user_data: rawptr = nil,
) {
  g_callback_data.resize_proc = resize_proc
  g_callback_data.user_data = user_data

  glfw.SetFramebufferSizeCallback(auto_cast window, _glfw_framebuffer_size_callback)
}

SURFACE_GL_PROC_ADDRESS :: glfw.gl_set_proc_address

//===========================
// os utils

surface_get_seconds :: proc() -> f32 { return f32(glfw.GetTime()) }


