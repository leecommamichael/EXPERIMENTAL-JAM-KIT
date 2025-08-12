Nodes are just positioned assets.

Saying no to:
	- physics engines
	- scripting languages
	- bespoke (textual) shader languages
	- nodes providing data/signals
	- multiple renderers
	- loads of nodes
	- deferred scheduling async code

Maybe someday:
	- shader graph

Philosophy:
	1. The game is the editor.
	2. Read it. This isn't off-the-shelf.

How to make a game with it?
	1. During init, load all resources into memory.
	2. Create node hierarchies using the resources.

resource(type, "path")
resource_type(data)

Or make "immediate resources".

Terraluna Milledec
	Machine:
	1 GPU
	1 CPU Core
	4GB RAM

	What can you with it?

