package main

import "core:strings"

// Convert a null-terminated fixed-size byte array to a string.
bats :: proc "contextless" (byte_array: []u8) -> string {
  return strings.truncate_to_byte(string(byte_array), 0)
}

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Mat4 :: matrix[4,4]f32

vec3 :: proc {
  vec3make,
  vec3of2,
  vec3of1,
}

vec3make :: #force_inline proc "contextless" (x: f32, y: f32, z: f32) -> [3]f32 {
  return {x, y, z}
}

vec3of2 :: #force_inline proc "contextless" (xy: Vec2, z: f32 = 0) -> Vec3 {
  return {xy.x, xy.y, z}
}
vec3of1 :: #force_inline proc "contextless" (xyz: f32 = 0) -> Vec3 {
  return {xyz, xyz, xyz}
}

vec4 :: proc {
  vec4of3
}

vec4of3 :: #force_inline proc "contextless" (vec3: Vec3, w: f32) -> Vec4 {
  return {vec3.x, vec3.y, vec3.z, w}
}