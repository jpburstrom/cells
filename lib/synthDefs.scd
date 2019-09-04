var defaultEnv = { |snd|
	snd * Env.asr(\atk.kr(0.02), 1, \rel.kr(0.02)).ar(2, \gate.kr(1));
};

var defaultAmp = { |snd|
	snd = snd * \amp.kr(1);
};

var selfReleasingEnv = { |snd|
	var duration = \duration.kr(inf).min(9999);
	snd = snd * Env.asr(\atk.kr(0.02), 1, \rel.kr(0.02)).ar(2, \gate.kr(1));
	snd = snd * Env([1, 1, 0], [duration, \rel.kr]).ar(2);
};

(1..8).do { |numChannels|

	SynthDef("cellMixer_%".format(numChannels), {
		var lvl = \amp.kr(1);
		var freeAfter = \freeWhenDone.kr(0); //Whether to free after fade
		var trig = Changed.kr(lvl) + Impulse.kr(0);
		var env = Env([0, lvl], [\fadetime.kr(0)], \curve.kr(-4)).ar(gate: trig);
		var snd = In.ar(\in.kr(0), numChannels);
		CheckBadValues.ar(snd);
		snd = Sanitize.ar(snd);
		// Use this to route private to main bus
		Out.ar(\out.kr(0), snd * env);
		// Free synth group, the rest is taken care of by cell
		FreeSelf.kr(Done.kr(env) * freeAfter);
	}).add;

	SynthDef("cellBufPlayer_%".format(numChannels), {

		var snd = PlayBuf.ar(numChannels, \bufnum.kr(0), \bufRate.kr(1.0), 1, \startPos.kr(0), \loop.kr(0));
		FreeSelf.kr(Done.kr(snd));

		snd = defaultEnv.value(snd);
		snd = defaultAmp.value(snd, numChannels);
		Out.ar(\out.kr(0), snd);
	}).add;

	SynthDef("cellDiskPlayer_%".format(numChannels), {
		var snd = DiskIn.ar(numChannels, \bufnum.kr(0), \loop.kr(0));

		FreeSelf.kr(Done.kr(snd));

		snd = selfReleasingEnv.value(snd);
		snd = defaultAmp.value(snd, numChannels);
		Out.ar(\out.kr(0), snd);
	}).add;

};