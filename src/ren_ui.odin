package main

Alignment :: enum { Start, Center, End }

Direction :: enum { Left, Right, Top, Bottom }

UI_Element_Type :: enum { Row, Column, Box, Root }

UI_Element :: struct {
	type:   UI_Element_Type,
	// main_axis_alignment:  Alignment,
	// cross_axis_alignment: Alignment,
	// padding:              [Direction]f32,
}

// Marks this part of the tree as a layout subtree.
ui_element :: proc (child: ^Entity, loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	entity.children = make([]^Entity, 1, context.temp_allocator)
	entity.children[0] = child
	entity.variant = UI_Element {
		type = .Root
	}
	entity.flags += { .Hidden }
	layout_subtree(entity)
	return entity
}

row :: proc (children: ..^Entity, loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	copy(entity.children, children)
	entity.variant = UI_Element {
		type = .Row
	}
	entity.flags += { .Hidden }
	return entity
}

column :: proc (children: ..^Entity, loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	entity.children = make([]^Entity, len(children), context.temp_allocator)
	copy(entity.children, children)
	entity.variant = UI_Element {
		type = .Column
	}
	entity.flags += { .Hidden }
	return entity
}

measure_entity :: proc (entity: ^Entity) -> Vec2 {
	switch variant in entity.variant {
	case Image_State:
		return entity.basis.scale.xy + entity.scale.xy
	case Sprite_State:
		return entity.basis.scale.xy + entity.scale.xy
	case Text_State:
		return measure_text(entity^)
	case UI_Element:
		switch variant.type {
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
	}
	panic("Exhaustive Switch")
}

// Modifies the sizes and positions of elements.
// To be done some time before render.
layout_subtree :: proc (root: ^Entity) {
	ui_element := root.variant.(UI_Element)
	// size := measure_entity(root)
	switch ui_element.type {
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
			child.position.y = main_axis_offset
			child.position.x = root.position.x
			child_size := measure_entity(child)
			main_axis_offset = child.position.y + child_size.y
			if child_size.x > max_cross_axis_size { max_cross_axis_size = child_size.x }
		}
		root.scale.x = main_axis_offset
		root.scale.y = max_cross_axis_size
	case .Box: break
	}
}

//
//
// button_area
// text_button  //
// image_button // ninepatch or not
//
// Anything that has to wait on layout can't be as immediate. Right?
// Well, no, layout just needs to be immediate.
// The thing is, layout needs to be recomputed if the state changes.
// And state is evaluated after game_step in (in fmwk_step) an attempt to let the user set properties after construction.
// So the whole point is, arguments passed to the entity can't be the deciding factor.
// This isn't a limitation of this API, though. 
//
// I cache entities between frames.
// I don't want the user to be manually adding children to a UI container.
// I want there to be some conditional which causes more or fewer things to be present.
// At the end of the day, you're the one passing the array of children.
//
// So when to do layout?
// I wouldn't even be against a flag which says immediate-or_not. I guess it doesn't matter.

UI_Element_State :: enum { Hovered, Pressed }
import "sugar"
button :: proc (loc := #caller_location) -> ^Entity {
	entity, is_new := do_entity(loc)
	if is_new {
		entity.variant = UI_Element {
			type = .Box
		}
		entity.flags += {.Collider_Enabled}
		entity.collider.shape = .Circle
		entity.collider.half_size = 50
		// This gist is that the GPU always gets the transform and the shader uses it.
		mesh := geom_make_quad(1, context.temp_allocator)
		entity.draw_command = ren_make_basic_draw_cmd(globals.instance_buffer, cast(int) entity.id, mesh.vertices[:], mesh.indices[:])
	}

	if entity_contains_entity(cursor, entity) {
		entity.ui += {.Hovered}
		if sugar.is_key_pressed(.Left_Mouse) {
			entity.ui += {.Pressed}
		}
	}

	return entity
}