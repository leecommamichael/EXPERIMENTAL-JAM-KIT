package main

import "audio"

// Iterators:
//   (T, bool: more_data)
//   (T, int, bool)
//
// Naming:
//   init - takes a pointer
//   new - returns a pointer and initialized to zero
//
//   make - returns a value (maybe containing pointers)
//   create - returns a pointer and initialized
//   
//   destroy - takes a pointer to deinitialize (and sometimes free if necessary)
//   free - takes a pointer (frees the pointer) but not destroy/deinit
//   delete - takes a value (frees a pointer)

////////////////////////////////////////////////////////////////////////////////
// Types
////////////////////////////////////////////////////////////////////////////////

Game_State :: struct {
	sfx_sink:   audio.Sink,
	music_sink: audio.Sink,
}

boat_mesh: []Vec3 = {
  // --- BOTTOM FACE (y=0) ---
  {0,0,0}, {1, 0, -1}, {1, 0, 1},
  {0,0,0}, {-1, 0, -1}, {1, 0, -1},
  {0,0,0}, {-1, 0, 1}, {-1, 0, -1},
  {0,0,0}, {-1, 0, 1}, {1, 0, 1}, 
  {-1, 0, 1}, {1, 0, 1}, {0, 0, 2},

  // --- TOP FACE (y=1) ---
  {0,1,0}, {1, 1, -1}, {1, 1, 1},
  {0,1,0}, {-1, 1, -1}, {1, 1, -1},
  {0,1,0}, {-1, 1, 1}, {-1, 1, -1},
  {0,1,0}, {-1, 1, 1}, {1, 1, 1}, 
  {-1, 1, 1}, {1, 1, 1}, {0, 1, 2},

  // --- SIDE WALLS (Connecting y=0 to y=1) ---
  
  // Right Wall
  {1, 0, -1}, {1, 1, -1}, {1, 1, 1},
  {1, 0, -1}, {1, 1, 1}, {1, 0, 1},

  // Front-Right Wall (to Tip)
  {1, 0, 1}, {1, 1, 1}, {0, 1, 2},
  {1, 0, 1}, {0, 1, 2}, {0, 0, 2},
// Front-Left Wall (from Tip)
  {0, 0, 2}, {0, 1, 2}, {-1, 1, 1},
  {0, 0, 2}, {-1, 1, 1}, {-1, 0, 1},

  // Left Wall
  {-1, 0, 1}, {-1, 1, 1}, {-1, 1, -1},
  {-1, 0, 1}, {-1, 1, -1}, {-1, 0, -1},

  // Back Wall
  {-1, 0, -1}, {-1, 1, -1}, {1, 1, -1},
  {-1, 0, -1}, {1, 1, -1}, {1, 0, -1},
}
