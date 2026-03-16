package main

import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "base:runtime"

// RATIONALE: I'm using u32 because OpenGL doesn't use 64bit index buffers.

Geom_Mesh2 :: struct {
  vertices: [dynamic]Ren_Vertex_Base,
  indices:  [dynamic]u32,
}

geom_make_hexgrid :: proc (
  rows: int = 512, // vertices
  cols: int = 512, // vertices
  hex_radius: f32,
) -> (mesh: Geom_Mesh2) {
  verts := rows * cols + (rows/2)
  mesh = {
    make([dynamic]Ren_Vertex_Base, verts),
    make([dynamic]u32, 0, 3*((2*(rows-1)*(cols-1)) + (rows-1)) )
  }
  assert(cols > 1)
  assert(rows > 1)
  X_GAP: f32 = hex_radius * 1.0
  Z_GAP: f32 = hex_radius * 0.866025 // sqrt(3)/2 for equilateral
  long_row: bool = false
  row: int = 0
  col: int = 0
  for i in 0..<verts {
    if ( long_row && col % (cols+1) == 0  \
    ||  !long_row && col %  cols    == 0) && col > 0 {
      col = 0
      row += 1
      long_row = !long_row
    }

    if long_row && col > 0 { // Avoids top and left edges
      a := u32( i-(cols+1) )
      b := u32( i-cols     )
      c := u32( i-1        )
      d := u32( i          )
      e := u32( i+cols     )
      f := u32( i+(cols+1) )
      if row == rows-1 {
        if col == cols { // BOTTOM RIGHT EDGE
          append(&mesh.indices, d,a,c)
        } else {          // BOTTOM EDGE
          append(&mesh.indices, d,b,a, d,a,c)
        }
      } else {
        if col == cols { // RIGHT EDGE
          append(&mesh.indices, d,a,c, d,c,e)
        } else {           // COMMON CASE
          append(&mesh.indices, d,b,a, d,a,c)
          append(&mesh.indices, d,c,e, d,e,f)
        }
      }
    }

    x_inset: f32 = long_row ? -0.5 * f32(X_GAP) : 0.0
    // x_inset: f32 = 0
    mesh.vertices[i].position.x = x_inset + f32(col) * X_GAP
    mesh.vertices[i].position.z =           f32(row) * Z_GAP
    col += 1
  }
  return
}

// RENAME? Really a cone.
// `len(vertices)` must be == `sides` (or `sides+1` if RingType.Start or .End)
geom_write_ring :: proc (
  vertices: []Ren_Vertex_Base,
  type: Ring_Type,
  ring_position: Vec3 = 0,
  tip_position: Vec3 = 0,
  sides: u32 = 12,
  radius: f32 = 1,
  transform: Mat4 = 1, // identity
) {
  bias: int = 0
  #partial switch type {
  case .Start:
    bias = 1
    vertices[0].position = (transform * vec4(tip_position,1)).xyz
  case .End:
    vertices[len(vertices)-1].position = (transform * vec4(tip_position,1)).xyz
  }
  // Find the step through the circle to mkeake N sides. 0...(360-theta_step)
  theta_step := glsl.radians_f32(360.0) / f32(sides)
  for i in 0 ..< int(sides) {
    theta := f32(i) * theta_step
    // I find it easier to look down at this shape from above,
    // So for my imagination, the sine component is mapped to the Z dimension.
    vertex: Vec4 = {
      math.cos(theta) * radius,
      0,
      math.sin(theta) * radius,
      1
    }
    vertices[i+bias] = Ren_Vertex_Base{position=(transform * vertex).xyz + ring_position}
  }
}

Ring_Type :: enum { Body, Start, End }

// RENAME? Really a cone.
geom_append_ring :: proc (
  vertices: ^[dynamic]Ren_Vertex_Base,
  type: Ring_Type,
  ring_position: Vec3 = 0,
  tip_position: Vec3 = 0,
  sides: u32 = 12,
  radius: f32 = 0.5,
  transform: Mat4 = 1,
  ) {
  verts_needed := int(sides)
  if type != .Body { 
    verts_needed += 1
  }
  v_len := len(vertices)
  err := resize(vertices, v_len + verts_needed)
  assert(err == nil)
  vs := vertices[v_len:][:verts_needed]
  geom_write_ring(vs, type, ring_position, tip_position, sides, radius, transform)
}

geom_make_cylinder :: proc (
  vector: Vec3,
  allocator: runtime.Allocator
) -> Geom_Mesh2 {
  mesh: Geom_Mesh2 = {
    make([dynamic]Ren_Vertex_Base, allocator),
    make([dynamic]u32, allocator),
  }

  CYLINDER_SIDES :: 12
  CYLINDER_RADIUS :: 0.1
  y_axis :: Vec3{0,1,0}
  axis := normalize(cross(y_axis, vector))
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
  angle := glsl.acos(dot(y_axis, normalize(vector)))
  // logg.infof("To output a vector pointing to %v, axis is %v, angle is %v", vector, axis, angle)

  // At this time, gizmos start from the origin.
  // This means the tail can simply be rotated (since it wont translate like the tip.)
  rotate_tail_ring := glsl.mat4Rotate(axis, angle)
  _translate_back  := glsl.mat4Translate(vector)
  // Two identical rings are made, and their transforms define the volume.
  // The tip's ring is translated away from the origin after rotating.
  rotate_tip_ring := _translate_back * rotate_tail_ring

  geom_append_ring(&mesh.vertices, .Start, 0,0, CYLINDER_SIDES, CYLINDER_RADIUS, rotate_tail_ring)
  geom_append_ring(&mesh.vertices, .End, 0,0, CYLINDER_SIDES, CYLINDER_RADIUS, rotate_tip_ring)

  // Now that the geometry has been baked in position according to the transforms,
  // We can build an index buffer to from triangles from the points.
  geom_append_ring_cap_indices(&mesh.indices, 0, CYLINDER_SIDES, .Start)
  geom_append_ring_cap_indices(&mesh.indices, 1+CYLINDER_SIDES, CYLINDER_SIDES, .End)
  geom_make_faces_between_rings(&mesh.indices, 1, 1+CYLINDER_SIDES, CYLINDER_SIDES)

  return mesh
}

geom_make_arrow :: proc (
  vector: Vec3,
  allocator: runtime.Allocator
) -> Geom_Mesh2 {
  mesh: Geom_Mesh2 = {
    make([dynamic]Ren_Vertex_Base, allocator),
    make([dynamic]u32, allocator),
  }

  CYLINDER_SIDES :: 12
  CYLINDER_RADIUS :: 0.1
  y_axis :: Vec3{0,1,0}
  axis := normalize(cross(y_axis, vector))
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
  angle := glsl.acos(dot(y_axis, normalize(vector)))
  // logg.infof("To output a vector pointing to %v, axis is %v, angle is %v", vector, axis, angle)

  // At this time, gizmos start from the origin.
  // This means the tail can simply be rotated (since it wont translate like the tip.)
  rotate_tail_ring := glsl.mat4Rotate(axis, angle)
  _translate_back  := glsl.mat4Translate(vector)
  // Two identical rings are made, and their transforms define the volume.
  // The tip's ring is translated away from the origin after rotating.
  rotate_tip_ring := _translate_back * rotate_tail_ring

  geom_append_ring(&mesh.vertices, .Start, 0,{0,0,0}, CYLINDER_SIDES, CYLINDER_RADIUS-0.05, rotate_tail_ring)
  geom_append_ring(&mesh.vertices, .Body,  0,0, CYLINDER_SIDES, CYLINDER_RADIUS-.05, rotate_tip_ring)
  geom_append_ring_cap_indices(&mesh.indices, 0, CYLINDER_SIDES, .Start)
  geom_make_faces_between_rings(&mesh.indices, 1, 1+CYLINDER_SIDES*1, CYLINDER_SIDES)

  geom_append_ring(&mesh.vertices, .End,   0,{0,.2,0}, CYLINDER_SIDES, CYLINDER_RADIUS, rotate_tip_ring) // pointy
  geom_make_faces_between_rings(&mesh.indices, 1+CYLINDER_SIDES, 1+CYLINDER_SIDES*2, CYLINDER_SIDES)
  geom_append_ring_cap_indices(&mesh.indices, 1+CYLINDER_SIDES*2, CYLINDER_SIDES, .End)

  // Now that the geometry has been baked in position according to the transforms,
  // We can build an index buffer to from triangles from the points.

  return mesh
}

geom_append_sphere :: proc(
    mesh: ^Geom_Mesh2, 
    position: Vec3 = 0, 
    radius: f32 = 0.5, 
    segments: u32 = 36, 
    rings: u32 = 18
) {
    start_index := cast(u32)len(mesh.vertices)

    reserve(&mesh.vertices, len(mesh.vertices) + int((rings + 1) * (segments + 1)))
    reserve(&mesh.indices, len(mesh.indices) + int(rings * segments * 6))

    for i in 0..=rings {
        v := f32(i) / f32(rings)
        theta := v * math.PI // lat

        sin_theta := math.sin(theta)
        cos_theta := math.cos(theta)

        for j in 0..=segments {
            u := f32(j) / f32(segments)
            phi := u * math.PI * 2.0 // lon

            sin_phi := math.sin(phi)
            cos_phi := math.cos(phi)

            x := cos_phi * sin_theta
            y := cos_theta
            z := sin_phi * sin_theta

            pos := position + (Vec3{x, y, z} * radius)
            
            append(&mesh.vertices, Ren_Vertex_Base{position = pos}) 
        }
    }

    for i in 0..<rings {
        for j in 0..<segments {
            first := start_index + (i * (segments + 1)) + j
            second := first + (segments + 1)

            // Triangle 1
            append(&mesh.indices, first)
            append(&mesh.indices, second)
            append(&mesh.indices, first + 1)

            // Triangle 2
            append(&mesh.indices, second)
            append(&mesh.indices, second + 1)
            append(&mesh.indices, first + 1)
        }
    }
}

geom_make_sphere :: proc(
    segments: u32 = 36, 
    rings: u32 = 18, 
    allocator := context.allocator
) -> Geom_Mesh2 {
    mesh: Geom_Mesh2 = {
        make([dynamic]Ren_Vertex_Base, allocator),
        make([dynamic]u32, allocator),
    }
    geom_append_sphere(&mesh, 0, 0.5, segments, rings)
    return mesh
}


// On the XY plane {0,0,0} is at the bottom left of the rect.
geom_write_rect :: proc (
  vertices: []Ren_Vertex_Base,
  indices:  []u32,
  start_of_mesh: u32,
  position: Vec3 = 0,
  size: Vec2 = 1,
) {
  TL := position + Vec3{ 0,      size.y, 0}
  TR := position + Vec3{ size.x, size.y, 0}
  BL := position
  BR := position + Vec3{ size.x, 0,      0}
  vertices[0] = Ren_Vertex_Base {TL, {0,0}, {}}
  vertices[1] = Ren_Vertex_Base {TR, {1,0}, {}}
  vertices[2] = Ren_Vertex_Base {BL, {0,1}, {}}
  vertices[3] = Ren_Vertex_Base {BR, {1,1}, {}}
  indices[0] = start_of_mesh + 0 /*TL*/
  indices[1] = start_of_mesh + 2 /*BL*/
  indices[2] = start_of_mesh + 1 /*TR*/
  indices[3] = start_of_mesh + 3 /*BR*/
  indices[4] = start_of_mesh + 1 /*TR*/
  indices[5] = start_of_mesh + 2 /*BL*/
}

geom_append_rect :: proc (
  mesh: ^Geom_Mesh2,
  position: Vec3,
  size: Vec2,
) -> runtime.Allocator_Error {
  num_verts := len(mesh.vertices)
  num_indices := len(mesh.indices)
  resize(&mesh.vertices, num_verts+4) or_return
  resize(&mesh.indices, num_indices+6) or_return
  geom_write_rect(
    mesh.vertices[num_verts:][:4],
    mesh.indices[num_indices:][:6],
    u32(num_verts),
    position,
    size)
  return nil
}

geom_make_rect :: proc (size: Vec2, allocator: runtime.Allocator) -> (Geom_Mesh2) {
  mesh := Geom_Mesh2 {
    vertices = make([dynamic]Ren_Vertex_Base, allocator),
    indices = make([dynamic]u32, allocator)
  }
  err := geom_append_rect(&mesh, position=0, size=size)
  assert(err == nil)
  return mesh
}

// On the XY plane {0,0,0} is at the center of the quad.
geom_write_quad :: proc (
  vertices: []Ren_Vertex_Base,
  indices:  []u32,
  start_of_mesh: u32,
  position: Vec3 = 0,
  size: Vec3 = 1,
) {
  p := size * 0.5
  TL := position + Vec3{ -p.x, p.y, 0, }
  TR := position + Vec3{  p.x, p.y, 0, }
  BL := position + Vec3{ -p.x,-p.y, 0, }
  BR := position + Vec3{  p.x,-p.y, 0, }
  vertices[0] = Ren_Vertex_Base {TL, {0,0}, {}}
  vertices[1] = Ren_Vertex_Base {TR, {1,0}, {}}
  vertices[2] = Ren_Vertex_Base {BL, {0,1}, {}}
  vertices[3] = Ren_Vertex_Base {BR, {1,1}, {}}
  indices[0] = start_of_mesh + 0 /*TL*/
  indices[1] = start_of_mesh + 2 /*BL*/
  indices[2] = start_of_mesh + 1 /*TR*/
  indices[3] = start_of_mesh + 3 /*BR*/
  indices[4] = start_of_mesh + 1 /*TR*/
  indices[5] = start_of_mesh + 2 /*BL*/
}

geom_append_quad :: proc (
  mesh: ^Geom_Mesh2,
  position: Vec3,
  size: Vec3,
) -> runtime.Allocator_Error {
  num_verts := len(mesh.vertices)
  num_indices := len(mesh.indices)
  resize(&mesh.vertices, num_verts+4) or_return
  resize(&mesh.indices, num_indices+6) or_return
  geom_write_quad(
    mesh.vertices[num_verts:][:4],
    mesh.indices[num_indices:][:6],
    u32(num_verts),
    position,
    size)
  return nil
}

geom_make_quad :: proc (size: Vec3, allocator: runtime.Allocator) -> Geom_Mesh2 {
  mesh := Geom_Mesh2 {
    vertices = make([dynamic]Ren_Vertex_Base, allocator),
    indices = make([dynamic]u32, allocator)
  }
  geom_append_quad(&mesh, position=0, size=size)
  return mesh
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
  squares_per_axis: u32,
  allocator: runtime.Allocator
) -> (result: Geom_Mesh2) {
  axis_vert_count: u32 = (squares_per_axis+1)
  axis_vert_count_squared := axis_vert_count * axis_vert_count
  vertices := make([dynamic]Ren_Vertex_Base, 0, axis_vert_count_squared, allocator)
  indices_per_square :: 6
  indices_needed := squares_per_axis * squares_per_axis * indices_per_square
  indices := make([dynamic]u32, 0, indices_needed, allocator)

  z: u32 = 0
  // 0 1 2 3 4 5
  // X X X x x x
  //     z     Z
  for i in 0 ..< axis_vert_count_squared {
    x := i % axis_vert_count
    z := i / axis_vert_count
    append(&vertices, Ren_Vertex_Base{
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
    append(&indices,
      TL, BL, TR, // Triangle 1
      BR, TR, BL) // Triangle 2
  }

  result.vertices = vertices
  result.indices = indices
  return
}

// needs sides+1 vertices.
geom_write_circle :: proc (
  vertices: []Ren_Vertex_Base,
  sides:    int,
  position: Vec3,
  radius:   f32,
) {
  // Begin by appending zero. (center point)
  vertices[0] = Ren_Vertex_Base { position = position + Vec4{0,0,0,1}.xyz }

  // Find the step through the circle to make N sides. 0...(360-theta_step)
  theta_step := glsl.radians_f32(360.0) / f32(sides)
  for i in 0 ..< sides {
    theta := f32(i) * theta_step
    // I find it easier to look down at this shape from above,
    // So for my imagination, the sine component is mapped to the Z dimension.
    vertices[i+1] = { position = position + {
      glsl.cos(theta) * radius,
      glsl.sin(theta) * radius,
      0,
    }}
  }
}

geom_append_circle :: proc (
  mesh: ^Geom_Mesh2,
  sides:    int,
  position: Vec3,
  radius:   f32,
) -> runtime.Allocator_Error {
  num_verts := len(mesh.vertices)
  resize(&mesh.vertices, num_verts+sides+1) or_return
  geom_write_circle(mesh.vertices[num_verts:][:sides+1], sides, position, radius)

  geom_append_ring_cap_indices(&mesh.indices, u32(num_verts), u32(sides), .Start)
  return nil
}

// start_of_mesh is both the center-point, and first vertex.
geom_append_ring_cap_indices :: proc (
  indices: ^[dynamic]u32,
  start_of_mesh: u32,
  sides_in_mesh: u32,
  type: Ring_Type
) {
  if type == .Start {
    // first, create the last triangle.
    append(indices, start_of_mesh + 1)
    append(indices, start_of_mesh)
    append(indices, start_of_mesh + sides_in_mesh)
    // create the rest
    for i in 1 ..< sides_in_mesh {
      append(indices, start_of_mesh + i + 1) // cant be zero.
      append(indices, start_of_mesh)
      append(indices, start_of_mesh + i)
    }
  } else if type == .End {
    for i in 0 ..< sides_in_mesh - 1 {
      append(indices, start_of_mesh + i + 1)
      append(indices, start_of_mesh + sides_in_mesh)
      append(indices, start_of_mesh + i)
    }
    append(indices, start_of_mesh + sides_in_mesh - 1)
    append(indices, start_of_mesh + sides_in_mesh)
    append(indices, start_of_mesh)
  } else {
    log.errorf("Body-ring indices form tris which form walls, not caps.")
    return
  }
}

// mesh1_1 is the first point of a pair along mesh1.
// Note that .Start rings begin with a center-point.
// Note that .End   rings end   with a center-point.
// This proc should not operate on center points!
geom_make_faces_between_rings :: proc (
  indices: ^[dynamic]u32,
  start_of_mesh1: u32,
  start_of_mesh2: u32,
  sides_in_meshes: u32,
) {
  for i in 0 ..< sides_in_meshes - 1 {
    // Construct a quad face with 2 triangles.
    mesh1_1 := start_of_mesh1 + i
    mesh2_1 := start_of_mesh2 + i
    mesh1_2 := start_of_mesh1 + i + 1
    mesh2_2 := start_of_mesh2 + i + 1

    append(indices, mesh2_2)
    append(indices, mesh1_1)
    append(indices, mesh2_1)

    append(indices, mesh2_2)
    append(indices, mesh1_2)
    append(indices, mesh1_1)
  }

  mesh1_1 := start_of_mesh1 + sides_in_meshes - 1 
  mesh2_1 := start_of_mesh2 + sides_in_meshes - 1
  mesh1_2 := start_of_mesh1
  mesh2_2 := start_of_mesh2
  append(indices, mesh2_2)
  append(indices, mesh1_1)
  append(indices, mesh2_1)

  append(indices, mesh2_2)
  append(indices, mesh1_2)
  append(indices, mesh1_1)
}

make_circle_2D :: proc (
  radius: f32,
  sides: int = 32,
  allocator: runtime.Allocator
) -> Geom_Mesh2 {
  verts := make([dynamic]Ren_Vertex_Base, allocator)
  resize(&verts, sides+1)
  geom_write_circle(verts[0:sides+1], sides, 0, radius)
  VERTS_PER_CAP: u32 = cast(u32) sides + 1 // counting center-point

  // Now that the geometry has been baked in position according to the transforms,
  // We can build an index buffer to from triagles from the points.
  indices: [dynamic]u32 = make([dynamic]u32)
  EDGE_SEGMENTS: u32 = cast(u32) sides
  geom_append_ring_cap_indices(&indices, 0, EDGE_SEGMENTS, .Start)

  return { verts, indices }
}

make_triangle_2D :: proc (allocator: runtime.Allocator) -> Geom_Mesh2 {
  verts := make([dynamic]Ren_Vertex_Base, allocator)
  append(&verts, Ren_Vertex_Base{position = Vec3{-1,1,0}})
  append(&verts, Ren_Vertex_Base{position = Vec3{1,1,0}})
  append(&verts, Ren_Vertex_Base{position = Vec3{0,-1,0}})
  indices: [dynamic]u32 = make([dynamic]u32, allocator)
  append(&indices, 0)
  append(&indices, 1)
  append(&indices, 2)
  return { verts, indices }
}

