I decided I'd be able to skip some serious data-transfer if I move my water simulation to the vertex shader.
The first snag was deciding x and z coordinates.
I removed the plane-size parameter, such that each box in the grid is actually one unit wide.
This means I can define y in terms of x and z. Great! That's basically just sampling.
This access pattern is naturally portable to the GPU now.

The next snag was that I couldn't really see what was going on. If my results were right.
So I decided to toss in Phong lighting.
Now I've got to write some surface normals, but oh wait! Do people animate those?
Can this be convincing water without animated normals?

Also, how do people _use_ normals in practice?
I see some are face-normals, and others vertex-normals. What's that about?
How do you even do face-normals for a cube if two sides share the vertices of an edge?

Well, it turns out that in this case; vertices are duplicated along edges.
You've got to do that in aide of normal-mapping. Pretty hacky stuff. Poor computer.

So I can't sleep now that I've got this problem. It's time to solve it.
Plan A:
	1. Generate a heightmap on the CPU.
	2. Sample it in the shader to derive normals and position.

Plan B:
	1. Implicit Surface Equation in shader
	2. Sample the surface at u,v and neighboring points to construct a normal.
	3. Use your basis vectors to construct a tangent and bitangent. You've now got 3D.

I need some control over this water.
1. Ramping off of tall waves
2. A wake that follows your boat
3. Designed locations and patterns for wave-emitters.

The implicit surface is certainly still possible while doing this,
but it would work a lot like a lighting system would. Which is pretty complex.
I'd have to upload data-descriptions of wave emitters and boats. Basically all game objects.
Then have the vertex shader consider all effects not unlike an SDF, then emit a point.

This wouldn't even be very realistic unless I sent a delta-time to the gpu,
and sampled the change in wave-forms between frames to simulate the imparted forces between emitters.
That's still not something I'd do on the CPU, but it'd certainly feel more natural there.

So I think I'll opt for Plan A since it's a bit simpler. If it performs OK on my laptop, I'll ship it.