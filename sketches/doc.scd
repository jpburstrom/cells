/*
Player should:
- Be able to play on different servers
- reset state on play
- track duration from play start
- know about its parent
- insert "progress" as an event key (0-1)
- read from bus
- have macro parameters that can be gui'd
- have global volume parameter
- play in own group
- have trim volume
- have volume envelope
- have envelopes for other params
- have LFOs
*/
SynthDef(\test, { arg out=0, freq=440, amp=0.1, pan=0, gate=1;
	var z;
	z = LPF.ar(
		Mix.new(VarSaw.ar(freq + [0, Rand(-0.4,0.0), Rand(0.0,0.4)], 0, 0.3, 0.3)),
		XLine.kr(Rand(4000,5000), Rand(2500,3200), 1)
	) * Linen.kr(gate, 0.01, 0.7, 0.3, 2);
	Out.ar(out, Pan2.ar(z, pan, amp));
}, [\ir]).add;
(
p = Require("lib/protos/serverPlayer").clone {
	var clock = TempoClock();

	~fadeInTime = 1;
	~fadeOutTime = 1;


	~factory.make {
		~synths = { |buses, parentGroup, fadeInTime, fadeOutTime, server|
			~volume = {
				var lvl = \lvl.kr(1);
				var trig = Changed.kr(lvl) + Impulse.kr(0);
				var env = Env([0, lvl], [\fadetime.kr(1)], -16).ar(gate: trig).poll;
				//NB: Doesn't work with offsetOut synth (causes clicks)
				ReplaceOut.ar(buses.out, In.ar(buses.out, 2) * env);
				Free.kr(TDelay.kr(Done.kr(env) * \freeGroup.kr(0), 1), parentGroup.nodeID);
			}.play(parentGroup, [\fadetime, fadeInTime])
		}
	};

	~fadeIn = {
		~fadeTo.(1, ~fadeInTime);
	};

	~fadeOut = { |stop|
		if (stop == true) {
			~synths.volume.set(\freeGroup, 1);
		};
		~fadeTo.(0, ~fadeOutTime);
	};

	~fadeTo = { |lvl, time|
		~synths.volume.set(\fadetime, time);
		~synths.volume.set(\lvl, lvl);
	};

	~pattern = Pbind();

	~onPlay = {
		~parentGroupFreeMethod = nil;
		~parentGroup.register(true).onFree({
			~stop.value
		}.inEnvir);
		~player = ~pattern.play(clock, protoEvent: (
			out: ~buses.out,
			group: ~parentGroup
		));

	};

	~onStop = {
		"stop".postln;
		~player.stop;
		clock.clear;
	};

};
z.free;
p.play;
fork {
	0.1.wait;
	z = { ReplaceOut.ar(0, DC.ar(0).dup) }.play;
	p.fadeOut(true);
}
)

p.play
p.parentGroup.free
p.fadeOutTime = 1;
p.fadeOut(true);
p.fadeTo(2, 2)
p.stop
p.buses
p.synths

Group().perform(false)
