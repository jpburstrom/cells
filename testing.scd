(
Cue({
	~play = { "playing".postln };
	~stop = { "stop".postln }
}).play
)
.then(_.stop)