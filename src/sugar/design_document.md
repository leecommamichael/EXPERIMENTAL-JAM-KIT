This is a minimal platform layer that exists as a seed to start games.

////////////////////////////////////////////////////////////////////////////////

  Sugar is what you want, not what you need.

////////////////////////////////////////////////////////////////////////////////

Why does this exist?
- Unfortunately, game jams are judged primarily in the browser. Native apps don't
get the same attention that browser-games do. Odin doesn't support Emscripten, 
and for good reason, as it's some of the nasty bits of an OS written in Javascript.
- If you had to write it, you'd have another task that isn't making games.
- So Odin users can benefit from this reference implementation of various platform-layers.
- This is an experiment to find whether a, generally available, more-comprehensive 
Odin platform-abstraction package is a worthwhile endeavor.

Why is it minimal?
 - To be approachable, even to someoone that's starting with native code.
 - To be outgrown. Shippable programs tend to integrate deeply with the native platforms. Using 
platform abstraction packages in that scenario requires almost the same knowledge
which is needed to write your own platform code... which provides you much more
control than a package, so do it yourself when you're ready.

////////////////////////////////////////////////////////////////////////////////

  When you're committed to your project, remove this package.

////////////////////////////////////////////////////////////////////////////////

Take a look at the native library documentation for your system, and remove this package.
Creating _your own_ platform abstraction library is a worthwhile endeavor.
It teaches you the various approaches to app development each platform has taken.
You will acquire a sense of what is broadly possible with modern operating systems.
But if I give you that package, you won't get the experience of building it.
That means it has got to represent a much better offering, to enough people, than 
what we have today in the bindings to SDL and GLFW.

Why shouldn't I expand the package instead of removing it?
 - You need to type this code if it's unfamiliar to you.
 - You've already got a more robust solution in SDL bindings. Just use the better
thing now that you don't need web support.
 - Do not try to retain web support. It's a lot of work, and a large constraint.