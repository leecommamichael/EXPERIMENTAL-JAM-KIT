package main

import "base:runtime"

Axis :: enum { Horizontal, Vertical }

Alignment :: enum { Start, Center, End }

Direction :: enum { Left, Right, Up, Down }

UI_Element_Type :: enum { None, Row, Column, Box, Root }

UI_Element_State :: enum { Hovered, Pressed }

UI_Element :: struct {
	type:   UI_Element_Type,
	state: bit_set[UI_Element_State],
	focus: [Direction]^Entity,
	// main_axis_alignment:  Alignment,
	// cross_axis_alignment: Alignment,
	// padding:              [Direction]f32,
}

// Marks this part of the tree as a layout subtree.
ui_element :: proc (child: ^Entity, loc := #caller_location) -> ^Entity {
	// entity, is_new := do_entity(loc)
	// entity.children = make([]^Entity, 1, context.temp_allocator)
	// entity.children[0] = child
	// entity.ui = UI_Element {
	// 	type = .Root
	// }
	// entity.flags += { .Hidden }
	child.position.z = next_z()
	layout_subtree(child)
	return child
}

init_list_children :: proc (entity: ^Entity, main_axis: Axis) {
	num_children := len(entity.children)
	children := entity.children
	for i in 0..< num_children {
		next_or_wrap := i+1 if i+1 < num_children else 0
		next_main: Direction = .Right if main_axis == .Horizontal else .Down
		children[i].ui.focus[next_main] = children[next_or_wrap]

		previous_or_wrap := i-1 if i-1 >= 0 else i
		prev_main: Direction = .Left if main_axis == .Horizontal else .Up
		children[i].ui.focus[prev_main] = children[previous_or_wrap]

		children[i].parent = entity
	}
}

row :: proc (children: ..^Entity, loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	entity.ui.type = .Row
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	copy(entity.children, children)
	entity.flags += { .Hidden }
	init_list_children(entity, .Horizontal)
	return entity
}

column :: proc (children: ..^Entity, loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	entity.ui.type = .Column
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	copy(entity.children, children)
	entity.flags += { .Hidden }
	init_list_children(entity, .Vertical)
	return entity
}

measure_entity :: proc (entity: ^Entity) -> Vec2 {
	switch entity.ui.type {
	case .None: // Not a UI element, but some we can measure.
		switch variant in entity.variant {
		case Image_State:
			return entity.basis.scale.xy + entity.scale.xy
		case Sprite_State:
			return entity.basis.scale.xy + entity.scale.xy
		case Text_State:
			return measure_text(entity^)
		case Timed_Effect_State(Empty_Struct): // not visual
		}
	case .Root: 
		return measure_entity(entity.children[0])
	case .Row:
		size: Vec2
		for child in entity.children {
			child_size := measure_entity(child)
			size.x += child_size.x
			if child_size.y > size.y { size.y = child_size.y }
		}
		return size
	case .Column:
		size: Vec2
		for child in entity.children {
			child_size := measure_entity(child)
			size.y += child_size.y
			if child_size.x > size.x { size.x = child_size.x }
		}
		return size
	case .Box:
		return entity.basis.scale.xy + entity.scale.xy
	}
	
	panic("Exhaustive Switch")
}

// Modifies the sizes and positions of elements.
// Finalizes focus tree.
layout_subtree :: proc (root: ^Entity) {
	ui_element := root.ui
	z := next_z()
	// size := measure_entity(root)
	switch ui_element.type {
	case .None: // TODO: position and size the entity.variant
	case .Root:
		root.children[0].position = root.position
		root.children[0].scale = root.scale
		layout_subtree(root.children[0])
	case .Row:
		// sizes := make([dynamic]Vec2, context.temp_allocator)
		// 	append(&sizes, measure_entity(child))
		main_axis_offset: f32 = root.position.x
		max_cross_axis_size: f32
		for child in root.children {
			child.position.z = z
			child.position.x = main_axis_offset
			child.position.y = root.position.y
			child_size := measure_entity(child)
			main_axis_offset = child.position.x + child_size.x
			if child_size.y > max_cross_axis_size { max_cross_axis_size = child_size.y }
		}
		root.scale.x = main_axis_offset
		root.scale.y = max_cross_axis_size
	case .Column:
		main_axis_offset: f32 = root.position.y
		max_cross_axis_size: f32
		#reverse for child in root.children {
			child.position.z = z
			child.position.y = main_axis_offset
			child.position.x = root.position.x
			child_size := measure_entity(child)
			main_axis_offset = child.position.y + child_size.y
			if child_size.x > max_cross_axis_size { max_cross_axis_size = child_size.x }
		}
		root.scale.y = main_axis_offset
		root.scale.x = max_cross_axis_size
	case .Box:
		root.position.z = z
	}
}

import "sugar"
button :: proc (loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	if is_new {
		entity.ui = UI_Element {
			type = .Box
		}
		entity.flags += {.Collider_Enabled}
		entity.collider.shape = .Circle
		entity.collider.size = 44 / globals.canvas_stretch.x
		// This gist is that the GPU always gets the transform and the shader uses it.
		mesh := geom_make_quad(1, context.temp_allocator)
		entity.draw_command = ren_make_basic_draw_cmd(globals.instance_buffer, cast(int) entity.id, mesh.vertices[:], mesh.indices[:])
	}
	entity.position.z = next_z()

	if they_touch(cursor, entity) {
		entity.ui.state += {.Hovered}
		if sugar.is_key_pressed(.Left_Mouse) {
			entity.ui.state += {.Pressed}
		}
	}

	return entity
}