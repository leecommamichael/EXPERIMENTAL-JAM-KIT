2026_02_21_audio_notes.md

WebAudio uses a planar format. Not interleaved samples like stb.

Interleaved is the storage/playback format. It's reality.
So what to do?

1. Use decodeAudioData and _always_ compressed assets on web.
2. Embed elements in the DOM. Use DOM source nodes.
3. Use AudioWorkletNode
4. Don't use WebAudio. Use <audio>

<audio>         needs generating some HTML from the cache.
decodeAudioData is async and does some work.

These leave me in a pretty low-control situation.
I'm liking Karl's solution, but I'm not sure how it scales.

Fundamentally, there needs to be a queue, ring-buffer, and mixing logic.
Maybe that's just a better way to do things, and I'm being a noob.
I think that's probably what's going on but I don't want to back out now.
--------------------------------------------------------------------------------
So I guess converting the interleaved data from stb to planar is the way.
I can at least do that at-rest in the bundler.
That kind of ruins caching. Makes it flakey.

So perhaps at upload-time I'll just dupe the buffer and make it planar...
But I don't want to hurt the main thread.
--------------------------------------------------------------------------------
The planar audio requirement is dumb. I can't believe it's the only option.
Can I just play raw PCM?

:sigh: fuck.

Just wanna use my fast dev-cache...
But I'd need to embed the raw asset for web builds.
How hard is that?
Well, I know it'd copy more assets.
Fuck.

So just copy .pcm, and if it's .pcm then web can't do it.
I can't skip embedding some of these files, though.
--------------------------------------------------------------------------------
So I complicate my cache if I can't just play it.
If I don't split to a thread, I'll stutter.
This will take time to make planar, but that'd happen anyway. (natively, tho)
--------------------------------------------------------------------------------
God, what to do. I hate this.

I don't feel like fucking with assets right now.
I'm just going to eat the startup stutter. God I hate this.