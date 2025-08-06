package main

import "core:math"
import "core:math/linalg/glsl"
import "base:runtime"


// **TODO: make these slices, not dynamic arrays?
//         can still use dyanmic arrays to create the data.
//         it just doesn't help the interface, right?
//         well, perhaps it doesn't harm it, I'm just afraid making a dynarray is heavier.
Geom_Mesh :: struct {
  vertices: [dynamic]Vec3,
  indices:  [dynamic]uint,
  texcoord: [dynamic]Vec2,
}

// Order of vertices of a pillar cap.
// 4     3     2
//   ┌───┬───┐  
//   │       │
// 5 ├ ─ 0 ─ ┤ 1
//   │       │
//   └───┴───┘
// 6     7     8
geom_make_pillar_cap :: proc (
  mesh: ^[dynamic]Vec3,
  pillar_size: Vec3,
  top: bool // or bottom face
) {
  // We want to center the prism around zero so it can be rotated easily.
  // This means halving the input sizes to form the -min,max coordinates.
  halves := pillar_size * 0.5
  x := halves.x
  y := halves.y if top else -halves.y
  z := halves.z
  assert(mesh != nil)
  append(mesh, Vec3{ 0, y, 0}) // 0
  append(mesh, Vec3{ x, y, 0}) // 1
  append(mesh, Vec3{ x, y, z}) // 2
  append(mesh, Vec3{ 0, y, z}) // 3
  append(mesh, Vec3{-x, y, z}) // 4
  append(mesh, Vec3{-x, y, 0}) // 5
  append(mesh, Vec3{-x, y,-z}) // 6
  append(mesh, Vec3{ 0, y,-z}) // 7
  append(mesh, Vec3{ x, y,-z}) // 8
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
  indices: ^[dynamic]uint,
  start_of_mesh: uint,
  sides_in_mesh: uint,
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
  indices: ^[dynamic]uint,
  start_of_mesh1: uint,
  start_of_mesh2: uint,
  sides_in_meshes: uint,
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
  verts_per_mesh: uint : CYLINDER_SIDES + 1 // plus center-point

  // Now that the geometry has been baked in position according to the transforms,
  // We can build an index buffer to from triangles from the points.
  indices: [dynamic]uint = make([dynamic]uint)
  geom_make_cap_indices(&indices, 0, CYLINDER_SIDES)
  geom_make_cap_indices(&indices, verts_per_mesh, CYLINDER_SIDES)
  geom_make_faces_between_rings(&indices, 0, verts_per_mesh, CYLINDER_SIDES)

  return { mesh, indices, {}, }
}

geom_make_pillar :: proc (size: Vec3) -> Geom_Mesh {
  verts: [dynamic]Vec3 = make([dynamic]Vec3)
  geom_make_pillar_cap(&verts, size, true)
  geom_make_pillar_cap(&verts, size, false)
  VERTS_PER_CAP: uint : 9 // plus center-point

  // Now that the geometry has been baked in position according to the transforms,
  // We can build an index buffer to from triangles from the points.
  indices: [dynamic]uint = make([dynamic]uint)
  EDGE_SEGMENTS :: 8 // segments along the subdivided rect
  geom_make_cap_indices(&indices, 0, EDGE_SEGMENTS)
  geom_make_cap_indices(&indices, VERTS_PER_CAP, EDGE_SEGMENTS)
  geom_make_faces_between_rings(&indices, 0, VERTS_PER_CAP, EDGE_SEGMENTS)

  return { verts, indices, {}, }
}

// On the XY plane
geom_make_quad :: proc (
  size: glsl.vec2,
) -> Geom_Mesh {
using glsl
  p :: 0.5
  TL :: Vec3{ -p, p, 0, }
  TR :: Vec3{  p, p, 0, }
  BL :: Vec3{ -p,-p, 0, }
  BR :: Vec3{  p,-p, 0, }
  m: Geom_Mesh
  m.vertices = make([dynamic]vec3, 4)
  m.indices = make([dynamic]uint, 6)
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

  m.texcoord = make([dynamic]vec2, 4)
  m.texcoord[0] = { 0 , 0 } // TL
  m.texcoord[1] = { 1 , 0 } // TR
  m.texcoord[2] = { 0 , 1 } // BL
  m.texcoord[3] = { 1 , 1 } // BR 
  return m
}