(
Cell({
	~play = { "playing".postln };
	~stop = { "stop".postln }
}).play
)
.then(_.stop)

(
var cond = Condition(true);
fork {
	cond.wait;
	2.postln;
}
)
