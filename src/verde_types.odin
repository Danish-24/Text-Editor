package verde

import "core:math"

vec2_f32 :: [2]f32
vec4_f32 :: [4]f32

vec2_i32 :: [2]i32
vec4_i32 :: [4]i32

mat4x4_f32 :: matrix[4,4]f32

Range_2D :: struct {
  min, max : vec2_f32
}

Rect :: struct {
  x, y : f32,
  width, height: f32,
}

Pivot :: enum u8 {
  Top_Left,
  Top_Middle,
  Top_Right,
  
  Center_Left,
  Center_Middle,
  Center_Right,

  Bottom_Left,
  Bottom_Middle,
  Bottom_Right,
}

@(rodata) PIVOT_VEC2 := [Pivot]vec2_f32 {
  .Top_Left   = {0.0, 0.0},
  .Top_Middle = {0.5, 0.0},
  .Top_Right  = {1.0, 0.0},

  .Center_Left   = {0.0, 0.5},
  .Center_Middle = {0.5, 0.5},
  .Center_Right  = {1.0, 0.5},

  .Bottom_Left   = {0.0, 1.0},
  .Bottom_Middle = {0.5, 1.0},
  .Bottom_Right  = {1.0, 1.0},
}


smooth_damp :: proc "contextless" (
  current: $T,
  target: T,
  smooth_time: f32,
  dt: f32
) -> T {
  if dt <= 0 || smooth_time <= 0 {
    return target
  }

  rate := 2.0 / smooth_time
  x := rate * dt

  factor: f32
  if x < 0.0001 {
    factor = x * (1.0 - x*0.5 + x*x/6.0 - x*x*x/24.0)
  } else {
    factor = 1.0 - math.exp(-x)
  }

  return math.lerp(current, target, factor)
}

