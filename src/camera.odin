package main

import "core:log"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "sugar"

// Engine basis vectors (left handed)
RIGHT: Vec3 : {1, 0, 0} // rotation on is Pitch (i-hat, X, Pitch)
UP:    Vec3 : {0, 1, 0} // rotation on is Yaw   (j-hat, Y, Yaw)
FRONT: Vec3 : {0, 0, 1} // rotation on is Roll  (k-hat, Z, Roll)
RIGHT4: Vec4 : {1, 0, 0, 0}
UP4:    Vec4 : {0, 1, 0, 0}
FRONT4: Vec4 : {0, 0, 1, 0}

Camera3D :: struct {
  position: Vec3,
  right_rad: f32,
  up_rad:   f32,
}
