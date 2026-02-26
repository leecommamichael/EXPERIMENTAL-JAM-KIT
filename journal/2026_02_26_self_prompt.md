--------------------------------------------------------------------------------
2026_02_26_self_prompt.md

I will make a game like Wave Racer.
	I'm thinking more like Mario Kart water segments.
	The water has waves which the car rides on.
	The car can fall from the crest of a wave onto more water.
	The car does not submerge.
	When the car falls onto water, become a bit submerged but bob-up to the surface.

There are obstacles, ramps, and pick-ups.
--------------------------------------------------------------------------------
The Terrain

	Animateable with deformers which run on CPU and Vertex-shader.
	Deformers are parameterized equations sycned between CPU and GPU.

--------------------------------------------------------------------------------
The Kart

	- Stays level with the water/ground with "suspension" wiggle.
	- Skid/Drift for more turn-rate.
	- Turn-rate decreases with speed.

	- Stats 
		Speed Limit
		Acceleration(speed)
		Turn_Rate(accel, speed)
--------------------------------------------------------------------------------
The Track

	Not sure how to generate this other than authoring in Blender.
	I guess I'd need a way to save/load a track-file if done in-engine with shapes.

	- Venice
	- Drainways
	- Lake Race
--------------------------------------------------------------------------------
