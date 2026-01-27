package main

import "base:runtime"
import "core:fmt"
import "core:time"
import "core:log"
import "core:sys/windows"
import "core:math/rand"
import "sugar"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

@export
hot_reload :: proc (engine_globals: ^Globals, engine_gs: ^Game_State) {
	ensure(engine_gs != nil)
	ensure(engine_globals != nil)
	gs = engine_gs
	globals = engine_globals
	sugar.set_memory(&globals.sugar)
	sugar.load_gl()
	globals.hot_reloaded_this_frame = true
}

////////////////////////////////////////////////////////////////////////////////
// Brainless Minigame Jam: Simpler Times
////////////////////////////////////////////////////////////////////////////////
// RG35SP_RES: Vec2 = {640, 480}
// STEAM_DECK_RES: Vec2 = {1280, 800}

gs: ^Game_State

action_for_building :: proc (option: Build_Menu) -> (action: Action) {
	action.build_result = option

	switch option {
	case .Build_Barracks: action.cost = barracks_cost
	case .Build_Workshop: action.cost = workshop_cost
	case .Build_Path:     action.cost = path_cost
	case .Build_Aqueduct: action.cost = aqueduct_cost
	case .Build_Train:    action.cost = train_cost
	}
	return
}

action_for_upgrade :: proc (option: Upgrade_Menu) -> (action: Action) {
	action.upgrade_result = option
	action.one_off = true

	switch gs.upgrade_menu_state {
	case .Unit_Speed:    action.cost = unit_speed_cost
	case .Unit_Health:   action.cost = unit_health_cost
	case .Unit_Power:    action.cost = unit_power_cost
	case .Unit_Capacity: action.cost = unit_capacity_cost
	}
	return
}

action_for_mission :: proc (option: Mission_Menu) -> (action: Action) {
	action.mission = option

	switch gs.mission_menu_state {
	case .Laner_Gather_Resource:
		action.cost = gather_cost
	case .Laner_Fight:
		action.cost = fight_cost
	case .Spy_Tile:
		action.cost = spy_cost
	case .Spy_Sabotage_Tile:
		action.cost = sabotage_cost
		action.one_off = true
	}
	return action
}

action_completion_pct :: proc (it: Action) -> f32 {
	return f32(time.tick_diff(it.work_start_time, time.tick_now())) / f32(it.cost.time)
}

// INTENT: Adjust the cost of Resources so the correct # of leaders is reimbursed.
// INTENT: Substitutions make the thing simply-affordable.
estimate_cost :: proc (cost: Resources) -> Cost_Estimate {
	if gs.player.ore < cost.ore\
	&& gs.player.food < cost.food\
	&& gs.player.water < cost.water {
		return { can_simply_afford = false }
	}

	if gs.player.workers >= cost.workers\
	&& gs.player.leaders >= cost.leaders {
		return { can_simply_afford = true }
	}

	workers_needed := cost.workers - gs.player.workers
	if workers_needed > 0 {
		if gs.player.leaders < workers_needed {
			// Not enough leaders to cover worker shortage.
			return { can_simply_afford = false, can_afford_with_subs = false}
		}
	}

	estimate: Cost_Estimate = {
		can_simply_afford = false,
		can_afford_with_subs = true,
		sub_worker_cost = gs.player.workers,
		sub_leaders_to_reimburse = workers_needed,
		sub_workers_to_reimburse = gs.player.workers
	}
	return estimate
}

index_from_column_row :: proc (tile: [2]int) -> int {
	return (tile.x) + (tile.y * COLUMNS)
}

// In iterator in Odin is anything that:
// -> (T, bool)
// -> (T, int, bool)
//
// Iterates indexes in ascending-index order.
make_neighbors :: proc (
	#no_broadcast center: [2]int,
	allocator := context.temp_allocator,
) -> []^Tile {
	tiles := alias_slice_as_empty_dynamic(make([]^Tile, 8, allocator)) // 8 = direct neighbors in 8 directions.

	RIGHT_EDGE  :: COLUMNS-1
	LEFT_EDGE   :: 0
	BOTTOM_EDGE :: 0
	TOP_EDGE    :: ROWS-1
	on_right_edge  := center.x == RIGHT_EDGE
	on_left_edge   := center.x == LEFT_EDGE
	on_bottom_edge := center.y == BOTTOM_EDGE
	on_top_edge    := center.y == TOP_EDGE
	switch {
	// Corner Cases //////////////////////////////////////////////////////////////
	case on_bottom_edge && on_left_edge:
		append(&tiles,
			&gs.tiles[index_from_column_row({1, 0})],
			&gs.tiles[index_from_column_row({0, 1})],
			&gs.tiles[index_from_column_row({1, 1})],
		)
	case on_bottom_edge && on_right_edge:
		append(&tiles,
			&gs.tiles[index_from_column_row({RIGHT_EDGE-1, 0})],
			&gs.tiles[index_from_column_row({RIGHT_EDGE-1, 1})],
			&gs.tiles[index_from_column_row({RIGHT_EDGE  , 1})],
		)
	case on_top_edge && on_left_edge:
		append(&tiles,
			&gs.tiles[index_from_column_row({LEFT_EDGE  , TOP_EDGE-1})],
			&gs.tiles[index_from_column_row({LEFT_EDGE+1, TOP_EDGE-1})],
			&gs.tiles[index_from_column_row({LEFT_EDGE+1, TOP_EDGE  })],
		)
	case on_top_edge && on_right_edge:
		append(&tiles,
			&gs.tiles[index_from_column_row({RIGHT_EDGE-1, TOP_EDGE-1})],
			&gs.tiles[index_from_column_row({RIGHT_EDGE  , TOP_EDGE-1})],
			&gs.tiles[index_from_column_row({RIGHT_EDGE-1, TOP_EDGE  })],
		)
	// Edge Cases ////////////////////////////////////////////////////////////////
	case on_left_edge:
		append(&tiles,
			&gs.tiles[index_from_column_row(center + {0,-1})],
			&gs.tiles[index_from_column_row(center + {1,-1})],
			&gs.tiles[index_from_column_row(center + {1, 0})],
			&gs.tiles[index_from_column_row(center + {1, 1})],
			&gs.tiles[index_from_column_row(center + {0, 1})],
		)
	case on_right_edge:
		append(&tiles,
			&gs.tiles[index_from_column_row(center + { 0,-1})],
			&gs.tiles[index_from_column_row(center + {-1,-1})],
			&gs.tiles[index_from_column_row(center + {-1, 0})],
			&gs.tiles[index_from_column_row(center + {-1, 1})],
			&gs.tiles[index_from_column_row(center + { 0, 1})],
		)
	case on_bottom_edge:
		append(&tiles,
			&gs.tiles[index_from_column_row(center + {-1, 0})],
			&gs.tiles[index_from_column_row(center + {-1, 1})],
			&gs.tiles[index_from_column_row(center + { 0, 1})],
			&gs.tiles[index_from_column_row(center + { 1, 1})],
			&gs.tiles[index_from_column_row(center + { 1, 0})],
		)
	case on_top_edge:
		append(&tiles,
			&gs.tiles[index_from_column_row(center + {-1, 0})],
			&gs.tiles[index_from_column_row(center + {-1,-1})],
			&gs.tiles[index_from_column_row(center + { 0,-1})],
			&gs.tiles[index_from_column_row(center + { 1,-1})],
			&gs.tiles[index_from_column_row(center + { 1, 0})],
		)
	// Not a corner or an edge. //////////////////////////////////////////////////
	case:
		append(&tiles,
			&gs.tiles[index_from_column_row(center + {-1,-1})], // SW
			&gs.tiles[index_from_column_row(center + { 0,-1})], // S
			&gs.tiles[index_from_column_row(center + { 1,-1})], // SE

			&gs.tiles[index_from_column_row(center + {-1, 0})], // W
			&gs.tiles[index_from_column_row(center + { 1, 0})], // E

			&gs.tiles[index_from_column_row(center + {-1, 1})], // NW
			&gs.tiles[index_from_column_row(center + { 1, 1})], // NE
			&gs.tiles[index_from_column_row(center + { 0, 1})], // N
		)
	}

	return tiles[:]
}

try_start_action :: proc (tile: ^Tile, action: Action) -> (started: bool) {
	if tile == nil do return false

	if tile.owner == .Enemy {
	 return false // Maybe in future allow it but they fight.
	}

	action := action // Need to mutate it if substituting leaders for workers.
	estimate := estimate_cost(action.cost)
	switch {
	case estimate.can_simply_afford:
		simply_buy_action(action)
	case estimate.can_afford_with_subs:
		action.one_off = true // the game won't let you spend all your leaders permanently
		action.cost.workers = estimate.sub_worker_cost
		action.cost.leaders = estimate.sub_leaders_to_reimburse
		action.leaders_to_reimburse = estimate.sub_leaders_to_reimburse
		action.workers_to_reimburse = estimate.sub_workers_to_reimburse
		simply_buy_action(action)
	case: return false // can't afford
	}
	add_new_action(tile, action)
	return true
}

make_next_action_id :: proc () -> int {
	id := gs.next_action_id
	gs.next_action_id += 1
	return id
}

simply_buy_action :: proc (action: Action) {
	gs.player.ore -= action.cost.ore
	gs.player.food -= action.cost.food
	gs.player.water -= action.cost.water
	gs.player.workers -= action.cost.workers
	gs.player.leaders -= action.cost.leaders
}

// Spawn some units which go to the job site and work.
add_new_action :: proc (tile: ^Tile, action: Action) {
	action := action
	action.id = make_next_action_id()
	action.target = tile
	tile.owner = .Player
	append(&gs.actions, action)
	// INTENT: When a action starts through the menu, put them on the map
	//         such that it's easy to pick a new tile for a action.
	set_state(States.Overworld)
}

finish_action :: proc (action: ^Action) {
}

import gl "angle"
game_init :: proc () {
	gl.BindSampler(cast(u32) Texture_Unit.Framebuffer_Texture, globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Texture,             globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Font,                globals.ren.nearest_sampler)
	globals.cursor = make_entity()
	globals.cursor.flags += {.Hidden}
	globals.cursor.position.xy = globals.mouse_position.xy
	globals.draw_colliders = false
	globals.canvas_size_px = {640,400}
	globals.canvas_scaling = .None
	globals.canvas_stretching = .Integer_Aspect
	globals.canvas_stretching = .Integer_Aspect

	r := rand.create(10)
	context.random_generator = rand.default_random_generator(&r)
	// How many ore, food, water to spawn?
	// Where to spawn them?
	// Well, there are 936 tiles.
	// if 1% chance for food, water, ore each, I'd get 9 of each.
	// So there's a relation between N tiles and N desired resources.
	// Let's say I want to spawn 5 things, SOMEWHAT evenly spaced through the tiles.
	// So I don't really want randomness...
	ore_remaining := 6
	water_remaining := 6
	food_remaining := 6

	gs = new(Game_State)
	gs.tiles = make([]Tile, TILES)
	gs.next_action_id = 1
	for i in 0..<TILES {
		tile: ^Tile = &gs.tiles[i]
		tile.index = i
		tile.column_row = {i % COLUMNS, i / COLUMNS}
		tile.neighbors = make_neighbors(tile.column_row, context.allocator)
		tile.resource = .Grass
		f01 := rand.float32()
		if f01 <= 0.005 && ore_remaining > 0 {
			tile.resource = .Ore
			ore_remaining -= 1
		} else if f01 <= 0.01 && food_remaining > 0 {
			tile.resource = .Food
			food_remaining -= 1
		} else if f01 < 0.015 && water_remaining > 0 {
			tile.resource = .Water
			water_remaining -= 1
		}
	}

	// Start tiles
	gs.tiles[0].resource = .Barracks
	gs.tiles[0].owner = .Player
	gs.tiles[TILES-1].resource = .Barracks
	gs.tiles[TILES-1].owner = .Enemy
	// Starting stats
	gs.player.workers = 0
	gs.player.food = 0
	gs.player.water = 0
	gs.player.ore = 0
	gs.player.leaders = 1
}

PANEL_SIZE: Vec2 = {120, 400}
SPACER :: 16

set_state :: proc (new_state: States) {
	if new_state != gs.state {
		gs.state_changed_this_frame = true
		gs.prev_state = gs.state
		gs.state = new_state
	}
}

state_changed :: proc () -> bool {
	if !gs.state_changed_this_frame do return false
	return gs.prev_state != gs.state
}

state_changed_from_to :: proc (prev, current: States) -> bool {
	if !gs.state_changed_this_frame do return false
	return prev == gs.prev_state && current == gs.state
}

get_focused_tile :: proc () -> ^Tile {
	return &gs.tiles[gs.focused_tile]
}

@export
game_step :: proc () {
	gs.state_changed_this_frame = false
	gs.events = {}

	switch gs.state {
	case .Overworld:
	// case .Selecting_First_Tile, .Selecting_Source_Tile, .Selecting_Target_Tile:
		// TODO: Wraps to 0 and TILES-1 on vertical movement.
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			gs.focused_tile = clamp(gs.focused_tile + COLUMNS, 0, TILES-1)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			gs.focused_tile = clamp(gs.focused_tile - COLUMNS, 0, TILES-1)
		}
		if sugar.on_button_press(.Left) || sugar.on_key_press(.A) {
			row := gs.focused_tile / COLUMNS 
			row_min := row * COLUMNS
			row_max := row_min + COLUMNS - 1
			gs.focused_tile = clamp(gs.focused_tile - 1, row_min, row_max)
		}
		if sugar.on_button_press(.Right) || sugar.on_key_press(.D) {
			row := gs.focused_tile / COLUMNS 
			row_min := row * COLUMNS
			row_max := row_min + COLUMNS - 1
			gs.focused_tile = clamp(gs.focused_tile + 1, row_min, row_max)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			if gs.action_source_barracks == nil\
			&& gs.action_target == nil {
				// make first selection with inferred intent
			} else if gs.action_source_barracks != nil {
				// second selection is intended as target (check)
			} else if gs.action_target != nil {
				// second selection is intended as source-barracks
			}
			set_state(.Panel_Menu)
			gs.events += {.Panel_Focused}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			// On tiles, nothing to go back to.
		}
	//////////////////////////////////////////////////////////////////////////////
	case .Panel_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.panel_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.panel_menu_state)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.panel_menu_state {
			case .Build_Menu:     set_state(.Build_Menu)
			case .Upgrade_Menu:   set_state(.Upgrade_Menu)
			case .Mission_Menu:   set_state(.Mission_Menu)
			}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			gs.events += {.Panel_Dropped_Focus}
			set_state(.Overworld)
		}
	//////////////////////////////////////////////////////////////////////////////
	case .Build_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.build_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.build_menu_state)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			try_start_action(get_focused_tile(), action_for_building(gs.build_menu_state))
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			set_state(.Panel_Menu)
		}
	//////////////////////////////////////////////////////////////////////////////
	case .Upgrade_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.upgrade_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.upgrade_menu_state)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.upgrade_menu_state {
			case .Unit_Speed:
			case .Unit_Health:
			case .Unit_Power:
			case .Unit_Capacity:
			}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			set_state(.Panel_Menu)
		}
	//////////////////////////////////////////////////////////////////////////////
	case .Mission_Menu:
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			enum_decrement_wrap(&gs.mission_menu_state)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			enum_increment_wrap(&gs.mission_menu_state)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			switch gs.mission_menu_state {
			case .Laner_Gather_Resource:
				try_start_action(get_focused_tile(), action_for_mission(gs.mission_menu_state))
				// Check the tile:
				// If the tile isn't reachable by path, send a leader.
				// If the tile _is_ reachable, send workers.
			case .Laner_Fight: // Retreats at low health. If speed too low, can die.
			case .Spy_Tile:
			case .Spy_Sabotage_Tile:
			}
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			set_state(.Panel_Menu)
		}
	} // switch //////////////////////////////////////////////////////////////////

	if sugar.on_button_press(.Y) || sugar.on_key_press(.E) {
		gs.zoom = !gs.zoom
	}

	bg := rect()
	bg.basis.scale.xy = globals.canvas_size_px
	uncenter_rect(bg)
	bg.color = color("#234")

	panel := rect()
	panel.basis.scale.xy = PANEL_SIZE
	uncenter_rect(panel)
	panel.color = color("#0126")

	for &action in gs.actions {
		switch action.state {
		case .Unplanned: // spawn units

		case .Awaiting_Assignees:
		case .In_Progress:
			if action_completion_pct(action) >= 1.0 {
				action.state = .Unplanned // Now go home
				if menu_option, ok := action.build_result.(Build_Menu); ok {
					new_type: Tile_Type
					switch menu_option {
					case .Build_Barracks: new_type = Tile_Type.Barracks
					case .Build_Workshop: new_type = Tile_Type.Workshop
					case .Build_Path:     new_type = Tile_Type.Path
					case .Build_Aqueduct: new_type = Tile_Type.Aqueduct
					case .Build_Train:    new_type = Tile_Type.Train
					}
					action.target.resource = new_type
				}
				if action.one_off {
					// Substitution & reimbursement only happens on one-off actions.
					gs.player.leaders += action.leaders_to_reimburse
					gs.player.workers += action.workers_to_reimburse
				} else {
					// pending
				}
			}
		} // switch state
	} // for action

	focused_tile := get_focused_tile()
	for i in 0..< TILES {
		basis: Transform
		basis.scale = TILE_SIZE_PX * tile_scale()
		basis.position.xy = basis.scale.x/2 + Vec2{TILE_SIZE_PX * 8 - 2, 5}
		tile: ^Tile = &gs.tiles[i]
		is_neighbor: bool; for n in focused_tile.neighbors do if n.index == i { is_neighbor = true; break }
		tile.focused = gs.focused_tile == i
		it := tile_entity(basis, tile, loop_hash("tile", i))
		gs.tiles[i].entity = it
	}

	menu := make([dynamic]^Entity, context.temp_allocator)
	append(&menu, 
		pad_box(16),
		section_list_item("LEADERS:", fmt.tprintf("%d", gs.player.leaders)),
		section_list_item("ORE:", fmt.tprintf("%d", gs.player.ore)),
		section_list_item("FOOD:", fmt.tprintf("%d", gs.player.food)),
		section_list_item("WATER:", fmt.tprintf("%d", gs.player.water)),
		section_list_item("WORKER:", fmt.tprintf("%d", gs.player.workers)),
		pad_box(16),
		section_list_item("THIS TILE:", fmt.tprintf("%v", focused_tile.resource)),
		pad_box(16),
	)
	switch gs.state {
	case .Overworld:    append(&menu, text("  ACTIONS:", .bold_pixel))
	case .Panel_Menu:   append(&menu, text("  ACTIONS:", .bold_pixel))
	case .Build_Menu:   append(&menu, text("< BUILD:", .bold_pixel))
	case .Upgrade_Menu: append(&menu, text("< UPGRADE:", .bold_pixel))
	case .Mission_Menu: append(&menu, text("< MISSION:", .bold_pixel))
	}
	menu_start: int = len(menu)
	if contains([]States{.Overworld, .Panel_Menu}, gs.state) {
		append(&menu, 
			text("  Build", .bold_pixel),
			text("  Upgrade", .bold_pixel),
			text("  Mission", .bold_pixel),
		)
	}
	switch gs.state {
	case .Overworld:
	//////////////////////////////////////////////////////////////////////////////
	case .Panel_Menu:
	//////////////////////////////////////////////////////////////////////////////
	case .Build_Menu:
		append(&menu,
			build_menu_list_item("  Barracks", .Build_Barracks),
			build_menu_list_item("  Workshop", .Build_Workshop),
			build_menu_list_item("  Path", .Build_Path),
			build_menu_list_item("  Aqueduct", .Build_Aqueduct),
			build_menu_list_item("  Train", .Build_Train),
		)
	//////////////////////////////////////////////////////////////////////////////
	case .Upgrade_Menu:
		append(&menu,
			upgrade_menu_list_item("  Unit Speed", .Unit_Speed),
			upgrade_menu_list_item("  Unit Health", .Unit_Health),
			upgrade_menu_list_item("  Unit Power", .Unit_Power),
			upgrade_menu_list_item("  Unit Capacity", .Unit_Capacity),
		)
	//////////////////////////////////////////////////////////////////////////////
	case .Mission_Menu:
		append(&menu,
			mission_menu_list_item("  Gather", .Laner_Gather_Resource),
			mission_menu_list_item("  Conquer", .Laner_Fight),
			mission_menu_list_item("  Spy on Tile", .Spy_Tile),
			mission_menu_list_item("  Sabotage Tile", .Spy_Sabotage_Tile),
		)
	} // switch //////////////////////////////////////////////////////////////////

	panel_list := column(..menu[:])
	panel_list_size := measure_entity(panel_list)
	height_to_pin_atop := PANEL_SIZE.y - panel_list_size.y
	col := ui_element(
		panel_list,
		position = Vec2{6, height_to_pin_atop},
	)

	// // lerp a highlighter from the tile to the menu
	menu_offset: int
	switch gs.state {
	case .Overworld:
	case .Panel_Menu:   menu_offset = cast(int) gs.panel_menu_state
	case .Build_Menu:   menu_offset = cast(int) gs.build_menu_state
	case .Upgrade_Menu: menu_offset = cast(int) gs.upgrade_menu_state
	case .Mission_Menu: menu_offset = cast(int) gs.mission_menu_state
	}
	hovered_text := menu[menu_start + menu_offset]
	menu_highlight := rect()
	@static is_animating := false
	menu_highlight_size := vec3({PANEL_SIZE.x, 16}, 1)
	menu_highlight.transform.scale = menu_highlight_size
	menu_highlight.transform.position.xy = hovered_text.position.xy + menu_highlight.scale.xy/2 - { 6, 4}
	// If the two objects have different bases, can't interpolate and store in xform.
	// The object will appear to come from the wrong location.

	menu_highlight.color = color("ff6")
	sinbh :: proc (theta: f32) -> f32 { return ((sin(theta) + 1) / 4) + 0.2 }
	@static time: f32; time += globals.tick
	menu_highlight.color.a = sinbh(2*time) * 0.5

	if hovered_cost, hovered, possible := vet_actions(); hovered {
		estimate := estimate_cost(hovered_cost)
		menu_highlight.color = color("f223")
		switch {
		case !possible: break
		case estimate.can_simply_afford: // no change to UI
		case estimate.can_afford_with_subs:
			menu_highlight.color = color("fff4")
			top_hat := image("leader16.ase")
			top_hat.flags += {.Skip_Interpolation}
			top_hat.position.xy = hovered_text.position.xy - {5, 4}
		}
	}

	Transform_Lerp_Data :: struct { sink: ^Transform, start: Transform, end: Transform }
	switch {
	case .Panel_Focused in gs.events:
		gs.action_source_barracks = nil
		gs.action_target = nil
		// dpending on what has been focused, fill in from and to.
		// depending on what's left ot fill out after the verb, select another.
		// find_path(&gs.tiles[0], focused_tile)
		menu_highlight.flags += {.Skip_Next_Interpolation}
		lerp_data: Transform_Lerp_Data = {
			sink  = &menu_highlight.transform,
			start = transform_add(focused_tile.entity.basis, focused_tile.entity.transform),
			end   = { menu_highlight.position, {}, menu_highlight_size },
		}
		effect := timed_effect(lerp_data, 0.1, proc (data: ^Transform_Lerp_Data, percent: f32) {
			data.sink^ = lerp_transform(data.start, data.end, percent)
		})
	case .Panel_Dropped_Focus in gs.events:
		menu_highlight.flags += {.Skip_Next_Interpolation}
		lerp_data: Transform_Lerp_Data = {
			sink  = &menu_highlight.transform,
			start = { menu_highlight.position, {}, menu_highlight_size },
			end   = transform_add(focused_tile.entity.basis, focused_tile.entity.transform),
		}
		effect := timed_effect(lerp_data, 0.1, proc (data: ^Transform_Lerp_Data, percent: f32) {
			data.sink^ = lerp_transform(data.start, data.end, percent)
			is_animating = true
		})
		effect.timeout = proc (data: ^Transform_Lerp_Data) {
			is_animating = false
		}
	} // switch

	if gs.state == .Overworld && !is_animating {
		menu_highlight.color.a = 0	
	}
} // game step

vet_actions :: proc () -> (cost: Resources, hovered: bool, possible: bool) {
	switch gs.state {
	case .Overworld: fallthrough
	case .Panel_Menu: return {}, false, false
	case .Build_Menu:
		switch gs.build_menu_state {
		case .Build_Barracks: cost = barracks_cost; hovered = true
		case .Build_Workshop: cost = workshop_cost; hovered = true
		case .Build_Path:     cost = path_cost;     hovered = true
		case .Build_Aqueduct: cost = aqueduct_cost; hovered = true
		case .Build_Train:    cost = train_cost;    hovered = true
		}
	case .Upgrade_Menu:
		switch gs.upgrade_menu_state {
		case .Unit_Speed:    cost = unit_speed_cost; hovered = true
		case .Unit_Health:   cost = unit_health_cost; hovered = true
		case .Unit_Power:    cost = unit_power_cost; hovered = true
		case .Unit_Capacity: cost = unit_capacity_cost; hovered = true
		}
	case .Mission_Menu:
		switch gs.mission_menu_state {
		case .Laner_Gather_Resource: cost = gather_cost; hovered = true
			found: bool; for n in get_focused_tile().neighbors do if is_gatherable(n^) { found = true; break }
			possible = found // need a gatherable resource.
		case .Laner_Fight:           cost = fight_cost; hovered = true
		case .Spy_Tile:              cost = spy_cost; hovered = true
		case .Spy_Sabotage_Tile:     cost = sabotage_cost; hovered = true
		}
	} // switch
	return
}

is_gatherable :: proc (tile: Tile) -> bool {
	switch tile.resource {
	case .Grass:    return false
	case .Ore:      return true
	case .Food:     return true
	case .Water:    return true
	case .Workshop: return false
	case .Market:   return false
	case .Barracks: return false
	case .Path:     return false
	case .Aqueduct: return false
	case .Train:    return false
	}
	panic("Exhaustive switch")
}

can_path_through :: proc (type: Tile_Type) -> bool {
	switch type {
	case .Grass:    return false
	case .Ore:      return true
	case .Food:     return true
	case .Water:    return true
	case .Workshop: return true
	case .Market:   return true
	case .Barracks: return true
	case .Path:     return true
	case .Aqueduct: return true
	case .Train:    return true
	}
	panic("Exhaustive switch")
}

// Given a resource, try to path a unit to it through roads.
find_path :: proc (start, dest: ^Tile) {
	graph := &gs.tiles
	UNKNOWN :: max(int)
	for &tile in graph {
		// "Visited" means we've measured distance to all neighbors from start,
		// and stored that distance on the neighbor. (this does not make that neighbor "visited")
		tile._search_visited = false
		if tile.index == start.index {
			tile._search_distance = 0
		} else {
			tile._search_distance = UNKNOWN
		}
	}

	for {
		min_distance: int = UNKNOWN
		min_unvisited: ^Tile
		// Of the unvisited tiles, 
		for &tile in graph { // Seek to remove from "unvisited"
			if !tile._search_visited\
			&& tile._search_distance < min_distance {
				min_distance = tile._search_distance
				min_unvisited = &tile
			}
		}
		if min_unvisited == dest do break // INTENT: Shortest path found.
		if min_unvisited == nil || min_distance == UNKNOWN do break
		// If we got here, we've got a graph-node to evaluate.
		assert(len(min_unvisited.neighbors) > 1)
		for &neighbor in min_unvisited.neighbors {
			neighbor := neighbor
			if !can_path_through(neighbor.resource) do continue
			neighbor._search_distance = min(
				neighbor._search_distance,
				min_unvisited._search_distance + 1)
			fmt.printfln("tile %d dist=%d", neighbor.index, neighbor._search_distance)
		}
		min_unvisited._search_visited = true
	}
}


////////////////////////////////////////////////////////////////////////////////
// Build Costs
////////////////////////////////////////////////////////////////////////////////

barracks_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,
}
workshop_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,
}
// Gathering cost is 1 worker + distance / speed
path_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,
}
aqueduct_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,

}
train_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 1,
	time = 1300 * time.Millisecond,
}

////////////////////////////////////////////////////////////////////////////////
// Upgrade Costs
////////////////////////////////////////////////////////////////////////////////
unit_speed_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 5300 * time.Millisecond,
}
unit_health_cost ::  Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 5300 * time.Millisecond,
}
unit_power_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 5300 * time.Millisecond,
}
unit_capacity_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 5300 * time.Millisecond,
}

////////////////////////////////////////////////////////////////////////////////
// Mission Costs
////////////////////////////////////////////////////////////////////////////////
gather_cost :: Resources {
	ore     = 0,
	food    = 0,
	water   = 0,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}
fight_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}
spy_cost :: Resources {
	ore     = 0,
	food    = 0,
	water   = 0,
	workers = 0,
	leaders = 0,
	time = 1300 * time.Millisecond // maybe make this the duration of spying
}
sabotage_cost :: Resources {
	ore     = 1,
	food    = 1,
	water   = 1,
	workers = 1,
	leaders = 0,
	time = 1300 * time.Millisecond
}

menu_highlight :: proc (
	cost: Resources
) -> ^Entity {
	assert(false); return nil
}

////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////

build_menu_list_item :: proc (
	label: string,
	value: Build_Menu,
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))
	_label.color = color("#aaa")

	estimate: Cost_Estimate
	switch value {
	case .Build_Barracks: estimate = estimate_cost(barracks_cost)
	case .Build_Workshop: estimate = estimate_cost(workshop_cost)
	case .Build_Path:     estimate = estimate_cost(path_cost)
	case .Build_Aqueduct: estimate = estimate_cost(aqueduct_cost)
	case .Build_Train:    estimate = estimate_cost(train_cost)
	}
	switch {
	case estimate.can_simply_afford:
		_label.color = color("#fff")
	case estimate.can_afford_with_subs:
		_label.color = color("#fff7")
	case:
		_label.color = color("#fff2")
	}
	return _label
}

upgrade_menu_list_item :: proc (
	label: string,
	value: Upgrade_Menu,
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))
	_label.color = color("#aaa")

	estimate: Cost_Estimate
	switch value {
	case .Unit_Speed:    estimate = estimate_cost(unit_speed_cost)
	case .Unit_Health:   estimate = estimate_cost(unit_health_cost)
	case .Unit_Power:    estimate = estimate_cost(unit_power_cost)
	case .Unit_Capacity: estimate = estimate_cost(unit_capacity_cost)
	}
	switch {
	case estimate.can_simply_afford:
		_label.color = color("#fff")
	case estimate.can_afford_with_subs:
		_label.color = color("#fff7")
	case:
		_label.color = color("#fff2")
	}
	return _label
}

mission_menu_list_item :: proc (
	label: string,
	value: Mission_Menu,
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))

	estimate: Cost_Estimate
	switch value {
	case .Laner_Gather_Resource: estimate = estimate_cost(gather_cost)
	case .Laner_Fight:           estimate = estimate_cost(fight_cost)
	case .Spy_Tile:              estimate = estimate_cost(spy_cost)
	case .Spy_Sabotage_Tile:     estimate = estimate_cost(sabotage_cost)
	}
	switch {
	case estimate.can_simply_afford:
		_label.color = color("#fff")
	case estimate.can_afford_with_subs:
		_label.color = color("#fff7")
	case:
		_label.color = color("#fff2")
	}
	return _label
}

section_list_item :: proc (
	label: string,
	value: string,
	hash: Hash = #caller_location
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))
	_label.color = color("#aaa")
	_value := text(value, .bold_pixel, hash=loop_hash(label, 2))
	return ui_element(
		column(
			_label,
			_value,
			hash = loop_hash(label, 3)
		)
	)
}

tile_scale :: proc () -> f32 { return 2.0 if gs.zoom else 1.0 }

tile_entity :: proc (
	basis: Transform,
	tile: ^Tile,
	hash: Hash = #caller_location,
) -> (^Entity, bool) #optional_ok {
	it, is_new := rect(hash)
	it.basis = basis
	it.position.xy = array_cast(tile.column_row, f32) * (TILE_GAP + basis.scale.x)
	if tile.resource == .Ore {
		img := image("ore16.ase", loop_hash("ore", tile.index))
		transform(img, it^)
	} else if tile.resource == .Food {
		img := image("food16.ase", loop_hash("food", tile.index))
		transform(img, it^)
	} else if tile.resource == .Water {
		shape := circle(loop_hash("water", tile.index))
		shape.basis = basis
		shape.position.xy = it.position.xy
		shape.color.rgb = resource_colors[.Water]
		it.color.rgb = 0
	} else if tile.resource == .Grass {
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Barracks {
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Path {
		it.color.rgb = resource_colors[tile.resource]
	} else {
		log.infof("undecorated resource: %v", tile.resource)
	}

	if tile._search_distance > 0 && tile._search_distance < max(int) {
		dist_label := text(fmt.tprintf("%d", tile._search_distance), hash=loop_hash("search_dbg", tile.index))
		dist_label.basis = basis
		dist_label.position.xy = it.position.xy
	}

	// TODO: Only do this if it's about building.
	// if tile.action.happening {
	// 	pct := action_completion_pct(tile.action)
	// 	it.basis.scale *= clamp(pct, 0, 1)
	// }

	if tile.focused {
		motion :: proc (theta: f32) -> f32 { return clamp(((sin(theta) + 1) / 2) + 0.2, 0.4, 0.7) }
		@static time: f32; time += globals.tick
		tile_highlight := rect(hash=loop_hash("focus", tile.index))
		tile_highlight.basis = it.basis
		tile_highlight.position.xy = it.position.xy
		tile_highlight.color = color("af6")
		tile_highlight.color.a = motion(4*time)
	}
	return it, is_new
}

resource_colors: [Tile_Type]Color3 = {
	.Grass    = {0.412, 0.651, 0.255},

	.Ore      = {0.859, 0.686, 0.235},
	.Food     = {0.761, 0.494, 0.184},
	.Water    = {0.208, 0.514, 0.749},

	.Workshop = {0.451, 0.224, 0.176},
	.Market   = {0.580, 0.329, 0.239},
	.Barracks = {0.769, 0.561, 0.376},

	.Path     = {0.541, 0.290, 0.192},
	.Aqueduct = {0.208, 0.514, 0.749},
	.Train    = {0.441, 0.190, 0.092},
}
