Cell {

	~level.out = 1;
	~level.rev = 0.1;

	~fadeOut.time = 5;
	~fadeOut.curve = 1;

	~fadeIn.time = 0.01;

	~numChannels = 2;

	~serverBoot = {

		SynthDef(\asdasd, {
		}).add;

	};


	~load = {
		~buf1 = Buffer.read(s, "/path/to/file.wav");
	};

	~play = {
		~buses.value;
		~groups.main;

		// Play an LFO
		// \busName is set from ~playCtl method
		// and stored in bus dictionary
		~playCtl.(\busName, {
			LFNoise2.kr(1).exprange(440, 880);
		}, [\arg, 23]);

		// Play a synth
		// By default, play on main bus
		// Inside main group
		~playSynth.(\foo, [\amp, buses.busName]);

		// Play fx
		// By default, play on main bus
		// Inside fx group
		~playFx.(\foo, [\mix, 0.2]);

		~playFx.({ |snd|
			(snd * 10).tanh * 0.1;
		});

		//Behind the scenes:
		//Volume level
		~volume = {
			var lvl = \level.kr(1);
			var trig = Changed.kr(lvl) + Impulse.kr(0);
			var env = Env([0, lvl], [\fadetime.kr(1)], -16).ar(gate: trig).poll;
			//NB: Doesn't work with offsetOut synth (causes clicks)
			ReplaceOut.ar(buses.out, In.ar(buses.out, 2) * env);
			Free.kr(TDelay.kr(Done.kr(env) * \freeGroup.kr(0), 1), parentGroup.nodeID);
		}.play(parentGroup, [\fadetime, fadeInTime])

	};

	~stop = {

		~playFadeOut.(5, \sin);

	};
};




	