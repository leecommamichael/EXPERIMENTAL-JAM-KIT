package main
import "core:time"

// init - takes a pointer
// new - returns a pointer and initialized to zero
//
// make - returns a value (maybe containing pointers)
// create - returns a pointer and initialized
// 
// destroy - takes a pointer to deinitialize (and sometimes free if necessary)
// free - takes a pointer (frees the pointer) but not destroy/deinit
// delete - takes a value (frees a pointer)

TILE_GAP :: 1
ROWS :: 23
COLUMNS :: 30
TILES :: ROWS * COLUMNS
TILE_SIZE_PX :: 16

Event :: enum {
	Panel_Focused,
	Panel_Dropped_Focus,
}

Game_State :: struct {
	next_action_id: int, // zero is reserved as invalid.
	actions: [dynamic]Action,
	events:  bit_set[Event],
	state_changed_this_frame: bool,
	prev_state:     States,
	state:          States,
	panel_menu_state:  Panel_Menu_State,
	//
	build_menu_state:   Build_Menu,
	upgrade_menu_state: Upgrade_Menu,
	mission_menu_state: Mission_Menu,
	//
	action_source_barracks: ^Tile,
	action_target:          ^Tile,
	focused_tile: int,
	player: Resources,
	enemy:  Resources,
	tiles:  []Tile,
	zoom:   bool,
}

States :: enum {
	// Selecting_First_Tile,
	// Selecting_Source_Tile,
	// Selecting_Target_Tile,
	Overworld,
	Panel_Menu,
	Build_Menu,
	Upgrade_Menu,
	Mission_Menu,
}

Panel_Menu_State :: enum {
	Build_Menu,
	Upgrade_Menu,
	Mission_Menu,
}

Build_Menu :: enum {
	Build_Barracks,
	Build_Workshop,
	Build_Path,
	Build_Aqueduct,
	Build_Train,
}
Upgrade_Menu :: enum {
	Unit_Speed,
	Unit_Health,
	Unit_Power,
	Unit_Capacity,
}
Mission_Menu :: enum {
	Laner_Gather_Resource,
	Laner_Fight, // Retreats at low health. If speed too low, can die.
	Spy_Tile,
	Spy_Sabotage_Tile,
}

// The last user to work the improvement.
Team :: enum {
	None,
	Player,
	Enemy,
}

Tile :: struct {
	entity:      ^Entity,
	neighbors:   []^Tile,
	index:       int,
	column_row:  [2]int,
	resource:    Tile_Type,
	owner:       Team, // Determines who is doing the action.
	focused:          bool,
	focus_neighbor:   bool,
	_search_visited:  bool,
	_search_distance: int,
}

Tile_Type :: enum {
	Grass,
	// Resources
	Ore,         // Build roads, workshop, markets, barracks
	Food, Water, // Modulates spawn rate
	// Buildings
	Workshop,    // improve/unlock units/resources
	Market,      // strengthen population
	Barracks,    // raise population
	Path,        // Allows non-scout units to move fast.
	Aqueduct,// Enhanced water source. Maybe auto resource.
	Train,// Railway
}

// To have a global array and add target param or not?
// Would happening and finish need to exist?
// Some actions are recurring. So a state-machine would make sense.

Action_State :: enum {
	Unplanned, // No workers heading in.
	Awaiting_Assignees,
	In_Progress,
}

// TODO? rename Fleet, Unit, Pawn, Piece, Command, Job
// This is like a command from which units spawn.
Action :: struct {
	id: int,
	// output/yield/result
	target:         ^Tile,
	build_result:   Maybe(Build_Menu),
	upgrade_result: Maybe(Upgrade_Menu),
	mission:        Maybe(Mission_Menu),
	// input
	cost:           Resources,
	one_off:        bool,
	// transient state
	state: Action_State,
	workers_to_reimburse: int,
	leaders_to_reimburse: int,
	work_start_time:      time.Tick, // start_action, finish_action
}

Unit_State :: enum {
	Invisible,
	Moving_To_Target,
	Working,
	Fighting,
	Moving_Home,
	Delivering,
}

Resources :: struct #all_or_none {
	ore:     int,
	food:    int,
	water:   int,
	workers: int,
	leaders: int,
	time:    time.Duration, // time dwelling on-location (not traversal)
}
BONKERS_RESOURCES :: Resources {
	ore     = max(int),
	food    = max(int),
	water   = max(int),
	workers = max(int),
	leaders = max(int),
	//
	time = 0,
}

Cost_Estimate :: struct {
	can_simply_afford: bool,
	can_afford_with_subs: bool,
	sub_worker_cost: int,
	sub_leaders_to_reimburse: int,
	sub_workers_to_reimburse: int,
}
