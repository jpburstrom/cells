Cell.addTemplate(\func, {
	~validateArgs = nil -> { |args|
		if (args.isEmpty.not) {
			args = [\play] ++ args;
		};
		args.postln
	}
}, \base);
Cell(\func, {
	"hello".postln;
}).play;

Cell.pattern(\pattern, Pbind()).pattern
Cell.func { "hello".postln }
Cl.func(\test, { 2.postln })


Cl(\test).play