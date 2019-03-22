c = Cell(nil, \synth).load
.then {
	().play; c.play

}
(
c = Cell({

	~stop = { |cond|
		"stop".postln;
		~server.bind {
			// Release synth.
			// Synths will take care of freeing the thing
			~synths.do(_.release);
		};
	};


}, \synth);
c.play
)

(foo:23).removeAt(\foo)