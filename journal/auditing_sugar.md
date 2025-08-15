Audit 8/15/2025

platform_calls_step should be a compile-time constant.
dt can duration_seconds could be sucked up into sugar.

``````````````````````````````````````````````````````````````````````
main :: proc() {
	ok := sugar.create_window([4]int{0,0, 900, 900}, "Wave Racer", use_gl = true)
	if !ok { panic("Window creation failed.") }

	// Do any initialization you'd like.

	when !sugar.platform_calls_step {
		for {
			sugar.step_dt()
			step(sugar.dt) or_break
			sugar.swap_buffers()
		}
	}
}
``````````````````````````````````````````````````````````````````````

It could be shorter if step is a function pointer... not sure if that's good.
``````````````````````````````````````````````````````````````````````
@export
step :: proc (dt: f64) -> (keep_going: bool) {
	event := sugar.poll_events()
	switch event {
	case .None:        // do nothing
	case .Should_Exit: return false	
	case .Resized:     // use sugar.resolution
	}
	// Add platform-independent code here.
	sugar.end_input_frame()
}
``````````````````````````````````````````````````````````````````````

Let's lean into the global data.
Put the global data pseudo-struct into it's own file for people to reference as API.
This thing ain't built to thread, and those that need it will do it.

Anything that is API must be in the interface file!

---

An issue with input:
	I need input events not to consume immediately, but instead to clear at the end of a frame.
	The point of them is to bind actions to keys. Is that valuable? Eh it's a stretch.
	It'd be nicer if they could just set an event listener.
	Way less work for me. But people don't like callbacks. I get it.

	So I need to enqueue clears. I'll use an enumerated array. <3 Odin

// GOTCHA:
//   You can't write if(action) {}; if (action) {}; and expect both to run.
//   EXPERIMENT: Write it as if that's not needed. Lift out to state if necessary.
//               e.g. "switch_mode: bool" so many places in the app can respond.

I did this experiment, and it's not good. Just muddies the intent.

---

An issue with input:
1. mouse buttons are keys?
2. no gamepad buttons
3. no axis
4. mouse should be "pointer".

Solutions:
	1. one seat, one of each device
	2. multiseat, multidevice


Naming:
  Mouse, Cursor, Pointer
  	Mouse may give the impression that it doesn't support touch.
  	But none of these are clear alone, and I need 2 words.
	Key, Switch, Button
	  Not Key because that's specific to a keyboard
	  Not Button because that doesn't remind me of a keyboard
	  Switch because that's the mechanical part name.

---

Decision:
	1 Keyboard
	1 Mouse
	N Gamepads
