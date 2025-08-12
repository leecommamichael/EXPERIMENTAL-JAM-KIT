package main

import "core:log"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "sugar"

// Engine basis vectors (left handed)
RIGHT: Vec3 : {1, 0, 0} // rotation on this is Pitch (i-hat, X, Pitch)
UP:    Vec3 : {0, 1, 0} // rotation on this is Yaw   (j-hat, Y, Yaw)
FRONT: Vec3 : {0, 0,-1} // rotation on this is Roll  (k-hat, Z, Roll)
RIGHT4: Vec4 : {1, 0, 0, 0}
UP4:    Vec4 : {0, 1, 0, 0}
FRONT4: Vec4 : {0, 0,-1, 0}

Camera3D :: struct {
  position:  Vec3,
  right_rad: f32,
  up_rad:    f32,
}

// Controls a camera with the mouse and keyboard.
tick_mouse_camera :: proc(camera: ^Camera3D, dt: f32) -> Mat4 {
  input: sugar.Input_Frame = sugar.g_state.input
  move_vel :: 6
  look_vel :: 0.33

  move_right    :=  1 if input.keys[.D].is_pressed else 0
  move_left     := -1 if input.keys[.A].is_pressed else 0
  move_forward  := -1 if input.keys[.W].is_pressed else 0
  move_backward :=  1 if input.keys[.S].is_pressed else 0

  strafe_vel := dt * move_vel * f32(move_right + move_left) // x
  depth_vel  := dt * move_vel * f32(move_forward + move_backward) // z
  hori_rot   := dt * look_vel * input.mouse.delta.x
  vert_rot   := dt * look_vel * input.mouse.delta.y

  // camera.right_rad += vert_rot // to look vertically, rotate on the side-vector of the orientation.
  camera.right_rad = clamp(camera.right_rad + vert_rot, -glsl.PI/2, glsl.PI/2)
  camera.up_rad    += hori_rot // to look horizontally, rotate on the up-vector of the orientation.
  // 1. Consider orientation after looking horizontally.
  right, front_xz := basis_from_yaw(camera.up_rad)

  camera.position += depth_vel * glsl.normalize(front_xz.xyz)
  camera.position += strafe_vel * glsl.normalize(right.xyz)

  rotate_about_right := glsl.mat4Rotate(right.xyz, camera.right_rad)
  u2 := rotate_about_right * UP4
  f3 := rotate_about_right * front_xz

  m: Mat4
  eye := camera.position
  x_scale := glsl.dot(right.xyz, eye)
  y_scale := glsl.dot(u2.xyz, eye)
  z_scale := glsl.dot(f3.xyz, eye)
  m[0] = { right.x, u2.x, -f3.x, 0 }
  m[1] = { right.y, u2.y, -f3.y, 0 }
  m[2] = { right.z, u2.z, -f3.z, 0 }
  m[3] = { -x_scale, -y_scale, z_scale, 1}
  return m
}

@(require_results)
basis_from_yaw :: proc (yaw: f32) -> (right, front: Vec4) {
  rotate_about_up := glsl.mat4Rotate(UP, yaw)
  right = rotate_about_up * vec4(RIGHT, 0)
  front = rotate_about_up * FRONT4
  return right, front
}