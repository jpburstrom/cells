(1..8).do { |numChannels|
	SynthDef("cellMixer_%".format(numChannels), {
		var lvl = \amp.kr(1);
		var freeAfter = \freeWhenDone.kr(0); //Whether to free after fade
		var trig = Changed.kr(lvl) + Impulse.kr(0);
		var env = Env([0, lvl], [\fadetime.kr(0)], \curve.kr(-4)).ar(gate: trig);
		// Use this to route private to main bus
		Out.ar(\out.kr(0), In.ar(\in.kr(0), numChannels) * env);
		// Free synth group, the rest is taken care of by cell
		FreeSelf.kr(Done.kr(env) * freeAfter);
	}).add
};

