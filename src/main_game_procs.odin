package main

import "core:time"
import "core:mem/virtual"

////////////////////////////////////////////////////////////////////////////////
// State
////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////
// Tile
////////////////////////////////////////////////////////////////////////////////

index_from_column_row :: proc (tile: [2]int) -> int {
	return (tile.x) + (tile.y * COLUMNS)
}

UNKNOWN_DISTANCE :: max(f32) // NOTE: not infinity
// Given a resource, try to path a unit to it through roads.
_find_path :: proc (
	start: ^Tile,
	dest: ^Tile,
	team: Team,
	leader: bool
) {
	graph := &gs.tiles
	for &tile in graph {
		// "Visited" means we've measured distance to all neighbors from start,
		// and stored that distance on the neighbor. (this does not make that neighbor "visited")
		tile._search_visited = false
		if tile.index == start.index {
			tile._search_distance = 0
		} else {
			tile._search_distance = UNKNOWN_DISTANCE
		}
	}

	for {
		min_distance := UNKNOWN_DISTANCE
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
		if min_unvisited == nil || min_distance == UNKNOWN_DISTANCE do break
		// If we got here, we've got a graph-node to evaluate.
		assert(len(min_unvisited.neighbors) > 1)
		for &tile in min_unvisited.neighbors {
			if team != .None && !leader { // INTENT: if (worker) ...
				if tile.resource in ROUGH_TERRAIN do continue
				if tile.resource in GATHERABLE {
					// INTENT: Workers cannot gather a resource without an entrance
					has_entrance: bool; for n in tile.neighbors do if n.resource in TRANSPORT {
						has_entrance = true; break
					}
					if !has_entrance do continue
				}
				if tile.resource in BUILDINGS && team != tile.owner {
					// INTENT: Workers cannot siege an enemy building without an entrance
					has_entrance: bool; for n in tile.neighbors do if n.resource in TRANSPORT {
						has_entrance = true; break
					}
					if !has_entrance do continue
				}
			}
			// INTENT: Make reachable by ascribing a known distance.
			d := distance(min_unvisited.entity.position.xy, tile.entity.position.xy)
			updated_dist := min(tile._search_distance, min_unvisited._search_distance + d)
			tile._search_distance = updated_dist
		}//for
		min_unvisited._search_visited = true
	}
}

// Returns len==0 if no path.
// Overwrites the supplied path.
set_path :: proc (
	start: ^Tile,
	dest: ^Tile,
	team: Team,
	leader: bool,
) {
	clear(&gs.selected_action.path)
	_find_path(start, dest, team, leader)
	if !(dest._search_distance < UNKNOWN_DISTANCE) do return

	end: ^Tile = dest
	inject_at_elem(&gs.selected_action.path, 0, end)
	for i := 0;; i+=1 {
		if i >= TILES {
			// Defensively avoid an endless loop.
			assert(false)
			clear(&gs.selected_action.path)
			return
		}

		nearest: ^Tile = end
		for neighbor in end.neighbors {
			if nearest == nil || neighbor._search_distance < end._search_distance {
				end = neighbor
			}
		}
		inject_at_elem(&gs.selected_action.path, 0, end)

		if end == start {
			break // path complete.
		}
	}
}

path_exists_between :: proc (actor, target: ^Tile, leader: bool) -> bool {
	_find_path(actor, target, actor.owner, leader)
	return target._search_distance < UNKNOWN_DISTANCE
}

get_focused_tile :: proc () -> ^Tile {
	return &gs.tiles[gs.focused_tile]
}

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

////////////////////////////////////////////////////////////////////////////////
// Action
////////////////////////////////////////////////////////////////////////////////

action_for_building :: proc (option: Build_Menu) -> (action: Action) {
	action.build_result = option

	switch option {
	case .Build_Barracks: action.cost = barracks_cost
	case .Build_Workshop: action.cost = workshop_cost
	case .Build_Path:     action.cost = path_cost
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
	return it.work_time / f32(time.duration_seconds(it.cost.time))
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

make_next_action_id :: proc () -> int {
	id := gs.next_action_id
	gs.next_action_id += 1
	return id
}

buy_action :: proc (action: Action) {
	gs.player.ore -= action.cost.ore
	gs.player.food -= action.cost.food
	gs.player.water -= action.cost.water
	gs.player.workers -= action.cost.workers
	gs.player.leaders -= action.cost.leaders
}

// Spawn some units which go to the job site and work.
add_new_action :: proc () {
	assert(gs.target != nil)
	action := gs.selected_action
	action.id = make_next_action_id()
	action.actor = gs.actor
	action.target = gs.target
	action.path = clone_to_dynamic(action.path[:])
	action.move_tiles_per_second = 1
	append(&gs.actions, action)
	virtual.arena_free_all(&gs.preview_arena) // preview is over. action is made.
	deselect_action()
	// INTENT: When a action starts through the menu, put them on the map
	//         such that it's easy to pick a new tile for a action.
	set_state(States.Selecting_Tile)
	gs.tile_select_mode = .First_Tile
}

unordered_remove_action :: proc (action: ^Action) {
	for it, i in gs.actions {
		if it.id == action.id {
			unordered_remove(&gs.actions, i)
			delete(action.path)
			return
		}
	}
	panic("Couldn't find the action to remove it.")
}

// Also adjusts the action's costs.
set_selected_action :: proc (action: Action) {
	gs.selected_action = action
	gs.has_selected_action = true
	assert(gs.selected_action.path == nil)
	gs.selected_action.path = make([dynamic]^Tile, gs.preview_allocator)
}

deselect_action :: proc () {
	gs.selected_action = {}
	gs.has_selected_action = false
}

// Actions are selected after a target OR source is selected.
vet_focused_menu_option :: proc () -> bool {
	if gs.target != nil {
		// Define Actions which can happen to Target
		if build, ok := gs.focused_action.build_result.?; ok {
			return can_build_on_tile(.Player, gs.target, build)
		} else if upgrade, ok := gs.focused_action.upgrade_result.?; ok {
			return can_upgrade_tile(.Player, gs.target, upgrade)
		} else if mission, ok := gs.focused_action.mission.?; ok {
			return can_do_mission_on_tile(.Player, gs.target, mission)
		} else {
			assert(false, "Bad action.")
		}
	}
	if gs.actor != nil {
		// Define Actions which can be done by Actor
		switch gs.actor.resource {
		case .Grass, .Ore, .Food, .Water, .Path:
			return false
		case .Workshop:
			upgrade, is_upgrade := gs.focused_action.mission.?
			return is_upgrade // TODO && can upgrade further
		case .Barracks:
			mission, is_mission := gs.focused_action.mission.?
			return is_mission // TODO && has enough workers/leaders
		}
	}
	assert(false, "Need at least one actor/target to vet a potential action (menu_option.)")
	return false
}

can_build_on_tile :: proc (team: Team, tile: ^Tile, build: Build_Menu) -> bool {
	if tile.owner != .None && tile.owner != team do return false
	if tile.resource not_in BUILDABLE_TERRAIN do return false
	return true // TODO use the `build` parameter or delete it.
}

can_upgrade_tile :: proc (team: Team, tile: ^Tile, upgrade: Upgrade_Menu) -> bool {
	if tile.owner != .None && tile.owner != team do return false
	if tile.resource != .Barracks do return false
	return true // TODO check if the tile can be upgraded further
}

can_do_mission_on_tile :: proc (team: Team, tile: ^Tile, mission: Mission_Menu) -> bool {
	switch mission {
	case .Laner_Gather_Resource:
		return tile.resource in GATHERABLE
	case .Laner_Fight:
		if tile.owner == team do return false // cant attack yourself
		return tile.resource in BUILDINGS || tile.resource in TRANSPORT
	case .Spy_Tile:
		return true
	case .Spy_Sabotage_Tile:
		return true
	}
	panic("Exhaustive Switch")
}

// Returns true if the `actor` can perform the `action` to the `target`
// TODO: re-vet cost since time can pass and resources can change.
vet_full_action :: proc (
	actor: ^Tile,
	action: Action,
	target: ^Tile,
) -> bool {
	assert(actor != nil && target != nil)
	// Define Actions which can be done by Actor
	switch actor.resource {
	case .Grass, .Ore, .Food, .Water, .Path:
		return false
	case .Workshop:
		if target.owner != .Player do return false // Can't improve what you don't own.
	case .Barracks:
		return path_exists_between(actor, target, action.cost.leaders > 0)
	}
	panic("Exhaustive Switch")
}
