package main

import "core:strings"
import "core:math"
import "core:log"
import "core:fmt"
import "core:time"
import "base:intrinsics"

// Convert a null-terminated fixed-size byte array to a string.
bats :: proc "contextless" (byte_array: []u8) -> string {
  return strings.truncate_to_byte(string(byte_array), 0)
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// This proc doesn't consider NaN/Inf to be "real"
is_real :: proc {
  is_real_float,
  is_real_array
}

// Returns true if the float wouldn't propagate errors through it's bit-pattern.
@(require_results)
is_real_float :: proc "contextless" (f: $T) -> bool 
  where intrinsics.type_is_float(T) 
{
  switch math.classify(f) {
  case .Normal, .Zero, .Neg_Zero: 
    return true
  case .Subnormal, .NaN, .Inf, .Neg_Inf:
    return false
  }
  return false
}

@(require_results)
is_real_array :: proc "contextless" (x: $Indistinct/[$N]$T) -> bool 
  where intrinsics.type_is_float(T) 
{
  for i in 0..<N {
    is_real := #force_inline is_real_float(x[i])
    if !is_real {
      return false
    }
  }
  return true
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Mat4 :: matrix[4,4]f32

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
vec3 :: proc {
  vec3make,
  vec3of2,
  vec3of1,
}

vec3make :: #force_inline proc "contextless" (x, y, z: f32) -> [3]f32 {
  return {x, y, z}
}

vec3of2 :: #force_inline proc "contextless" (xy: Vec2, z: f32 = 0) -> Vec3 {
  return {xy.x, xy.y, z}
}
vec3of1 :: #force_inline proc "contextless" (xyz: f32 = 0) -> Vec3 {
  return {xyz, xyz, xyz}
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
vec4 :: proc {
  vec4make,
  vec4of3
}

vec4make :: #force_inline proc "contextless" (x, y, z, w: f32) -> Vec4 {
  return {x, y, z, w}
}

vec4of3 :: #force_inline proc "contextless" (vec3: Vec3, w: f32) -> Vec4 {
  return {vec3.x, vec3.y, vec3.z, w}
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
vec2 :: #force_inline proc "contextless" (x, y: f32) -> [2]f32 {
  return {x, y}
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// A stopwatch timer for quick and dirty measurements.
log_timers: map[string]time.Tick

log_time :: proc (id: string) {
  if id in log_timers {
    tick := log_timers[id]
    duration := time.tick_diff(tick, time.tick_now())
    fmt.printfln("[TIMER] % 6.1fms %s", f64(duration) / f64(time.Millisecond), id)
    delete_key(&log_timers, id)
  } else {
    log_timers[id] = time.tick_now()
  }
}


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
type_uses :: intrinsics.type_is_subtype_of