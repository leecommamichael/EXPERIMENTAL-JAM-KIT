package main

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "base:runtime"

// RATIONALE: I'm using u32 because OpenGL doesn't use 64bit index buffers.

Geom_Mesh :: struct {
  vertices: [dynamic]Vec3,
  indices:  [dynamic]u32,
  texcoord: [dynamic]Vec2,
}

Geom_Mesh2 :: struct {
  vertices: [dynamic]Ren_Vertex_Base,
  indices:  [dynamic]u32,
}

// Prior to transformation, points are:
//  - a circle in the XZ plane
//  - centered on the origin
//  - wound counter-clockwise when looking at -Y (Down)
geom_make_ring :: proc (
  mesh: ^[dynamic]Vec3,
  sides: int,
  radius: f32,
  transform: Mat4,
) {
  assert(mesh != nil)
  // Begin by appending zero. (center point)
  append(mesh, (transform * Vec4{0,0,0,1}).xyz)

  // Find the step through the circle to make N sides. 0...(360-theta_step)
  theta_step := glsl.radians_f32(360.0) / f32(sides)
  for i in 0 ..< sides {
    theta := f32(i) * theta_step
    // I find it easier to look down at this shape from above,
    // So for my imagination, the sine component is mapped to the Z dimension.
    vertex: Vec4 = {
      math.cos(theta) * radius,
      0,
      math.sin(theta) * radius,
      1
    }
    append(mesh, (transform * vertex).xyz)
  }
}

// start_of_mesh is both the center-point, and first vertex.
geom_make_cap_indices :: proc (
  indices: ^[dynamic]u32,
  start_of_mesh: u32,
  sides_in_mesh: u32,
) {
  // first, create the last triangle.
  append(indices, start_of_mesh + 1)
  append(indices, start_of_mesh)
  append(indices, start_of_mesh + sides_in_mesh)
  // create the rest
  for i in 1 ..< sides_in_mesh {
    index := (start_of_mesh + i);
    append(indices, index + 1) // cant be zero.
    append(indices, start_of_mesh)
    append(indices, index)
  }
}

// Visualize this as creating faces between walls of a wheel.
// Or circumscribing polygons top-down, and connecting corresponding points.
geom_make_faces_between_rings :: proc (
  indices: ^[dynamic]u32,
  start_of_mesh1: u32,
  start_of_mesh2: u32,
  sides_in_meshes: u32,
) {
  // first, create the last triangle.
  mesh1_1 := start_of_mesh1 + sides_in_meshes
  mesh2_1 := start_of_mesh2 + sides_in_meshes
  mesh1_2 := start_of_mesh1 + 1
  mesh2_2 := start_of_mesh2 + 1
  append(indices, mesh2_2)
  append(indices, mesh1_1)
  append(indices, mesh2_1)

  append(indices, mesh2_2)
  append(indices, mesh1_2)
  append(indices, mesh1_1)
  // Zero is the center-point, so we skip it.
  for i in 1 ..< sides_in_meshes {
    // Construct a quad face with 2 triangles.
    mesh1_1 = start_of_mesh1 + i
    mesh2_1 = start_of_mesh2 + i
    mesh1_2 = start_of_mesh1 + i + 1
    mesh2_2 = start_of_mesh2 + i + 1

    append(indices, mesh2_2)
    append(indices, mesh1_1)
    append(indices, mesh2_1)

    append(indices, mesh2_2)
    append(indices, mesh1_2)
    append(indices, mesh1_1)
  }
}

geom_make_cylinder :: proc (
  vector: Vec3,
) -> Geom_Mesh {
using glsl
  CYLINDER_SIDES :: 12
  CYLINDER_RADIUS :: 0.1
  y_axis :: Vec3{0,1,0}
  axis  := normalize(cross(y_axis, vector))
  // if we got NaN, then the vector is the same in that component.
  if math.is_nan(axis.x) {
    axis.x = vector.x
  }
  if math.is_nan(axis.y) {
    axis.y = vector.y
  }
  if math.is_nan(axis.z) {
    axis.z = vector.z
  }
  angle := acos(dot(y_axis, normalize(vector)))
  // logg.infof("To output a vector pointing to %v, axis is %v, angle is %v", vector, axis, angle)

  // At this time, gizmos start from the origin.
  // This means the tail can simply be rotated (since it wont translate like the tip.)
  rotate_tail_ring := mat4Rotate(axis, angle)
  _translate_back  := mat4Translate(vector)
  // Two identical rings are made, and their transforms define the volume.
  // The tip's ring is translated away from the origin after rotating.
  rotate_tip_ring := _translate_back * rotate_tail_ring

  mesh: [dynamic]vec3 = make([dynamic]vec3)
  geom_make_ring(&mesh, CYLINDER_SIDES, CYLINDER_RADIUS, rotate_tail_ring)
  geom_make_ring(&mesh, CYLINDER_SIDES, CYLINDER_RADIUS, rotate_tip_ring)
  verts_per_mesh: u32 : CYLINDER_SIDES + 1 // plus center-point

  // Now that the geometry has been baked in position according to the transforms,
  // We can build an index buffer to from triangles from the points.
  indices: [dynamic]u32 = make([dynamic]u32)
  geom_make_cap_indices(&indices, 0, CYLINDER_SIDES)
  geom_make_cap_indices(&indices, verts_per_mesh, CYLINDER_SIDES)
  geom_make_faces_between_rings(&indices, 0, verts_per_mesh, CYLINDER_SIDES)

  return { mesh, indices, {}, }
}

// On the XY plane
geom_make_quad :: proc (
  size: Vec2,
) -> Geom_Mesh {
using glsl
  p :: 0.5
  TL :: Vec3{ -p, p, 0, }
  TR :: Vec3{  p, p, 0, }
  BL :: Vec3{ -p,-p, 0, }
  BR :: Vec3{  p,-p, 0, }
  m: Geom_Mesh
  m.vertices = make([dynamic]vec3, 0, 4)
  m.indices = make([dynamic]u32, 0, 6)
  m.vertices[0] = { TL.x * size.x , TL.y * size.y , 0 }
  m.vertices[1] = { TR.x * size.x , TR.y * size.y , 0 }
  m.vertices[2] = { BL.x * size.x , BL.y * size.y , 0 }
  m.vertices[3] = { BR.x * size.x , BR.y * size.y , 0 }
  m.indices[0] = 0 // TL
  m.indices[1] = 2 // BL
  m.indices[2] = 1 // TR
  m.indices[3] = 3 // BR
  m.indices[4] = 1 // TR
  m.indices[5] = 2 // BL

  m.texcoord = make([dynamic]vec2, 0, 4)
  m.texcoord[0] = { 0 , 0 } // TL
  m.texcoord[1] = { 1 , 0 } // TR
  m.texcoord[2] = { 0 , 1 } // BL
  m.texcoord[3] = { 1 , 1 } // BR 
  return m
}

// A grid of points along the XZ plane.
//
// 6----7----8
// |    |    |
// 3----4----5  Tri 0A: 3, 0, 4
// |    |    |  Tri 0B: 1, 4, 0
// 0----1----2
//
//
// We know the names of points, as labeled above. (indexes)
// The only task is to ensure inserting them in that order.
geom_make_xz_plane :: proc (
  squares_per_axis: u32
) -> (result: Geom_Mesh2) {
  axis_vert_count: u32 = (squares_per_axis+1)
  axis_vert_count_squared := axis_vert_count * axis_vert_count
  result.vertices = make([dynamic]Ren_Vertex_Base, 0, axis_vert_count_squared)
  indices_per_square :: 6
  indices_needed := squares_per_axis * squares_per_axis * indices_per_square
  result.indices = make([dynamic]u32, 0, indices_needed)

  z: u32 = 0
  // 0 1 2 3 4 5
  // X X X x x x
  //     z     Z
  for i in 0 ..< axis_vert_count_squared {
    x := i % axis_vert_count
    z := i / axis_vert_count
    append(&result.vertices, Ren_Vertex_Base{
      position = Vec3{
        f32(x),
        0,
        f32(z),
      } 
    })

    if (x+1) == axis_vert_count \
    || (z+1) == axis_vert_count {
      // As we insert a new triangle's worth of indices every iteration;
      // if we don't `continue`, the end of a row
      // will be stitched to the beginning of the next row.
      continue
    }

    BL:u32 = i
    BR:u32 = i + 1
    TL:u32 = i + axis_vert_count
    TR:u32 = i + axis_vert_count + 1
    append(&result.indices,
      TL, BL, TR, // Triangle 1
      BR, TR, BL) // Triangle 2
  }

  return
}

