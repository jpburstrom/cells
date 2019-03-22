//Cue, function style
(
{
	//Throwaway variables
	var revBus, buf, ptn;

	//Load is synchroneous -- waits until
	~load = { |self|
		buf = self.makeBuffer(self.samples.kick);
		bus = self.makeBus; //Default audio, 2 channels
		//Synth style notation
		//Use playfx when synth should be kept playing as long as other nodes are playing
		//eg will not keep cue playing
		rev = self.playfx(\reverb, [\in, revBus], \fx); //Out is defined by makeSynth
	};

	//Like spawner
	//Where is the responsibility for stopping?
	//Where is duration info?
	~play = { |self|

		//Event style notation
		//Cue will keep playing for entire duration of synth,
		//or until user is stopping
		self.play((instrument: \weirdDrone, \sendBus: revBus, sendAmp: 0.2));

		//We can wait
		//Current implementation uses forkIfNeeded for play
		//So this would cause a lock
		//Maybe use fork (throughout) and .wait/.then instead
		self.wait(10);

		//we have a spawner waiting to run stuff
		//pattern, delta, duration(?)
		self.par(Pbind(), 0, 10)

		//When all items have yielded, we stop and clean up., something like
		self.tailTime.wait;
		self.synths.do(_.release(0.1));
		self.fx.do(_.release(0.1));
		0.1.wait;
		self.stop

		//Maybe we need to differentiate between external stop and cleanup after all
		//patterns ahve ended
	};



}
)



(
//Hard stopping cue
fork {
	var g, t, p;
	//Cue plays in group
	g = Group();
	//Has its own clock
	t = TempoClock.new;
	//
	p = Pspawner({ |sp|
		sp.seq(Pbind(\group, g, \dur, Pwhite(0.01, 0.02)));
	}).play(t);
	1.wait;
	//bind to avoid node not found msgs
	s.bind {
		t.clear;
		p.stop;
		g.free;
	}
}
)
/*
- parent group
-- synth group
--- synth
-- fx group
--- synth
--- ...
-- output group
--- pre-fader routing
--- fader
--- post-fader routing
*/

/*
Cue responsibilities:
- Responding to triggers (play, stop, ...)
- Playing child objects (synths, patterns)
- Handling resources (buffers, buses)
- Fading, setting volume,
- Controlling synths/patterns with (macro) parameters
- Having internal tempo, possibly synced to others
- Playing on quant
- Grouping, routing
- Rendering (freezing)

Some cues use only subset of these. Some cues play on many servers. Cues can have 1 or 32 channels. Important not to hard code stuff, if not necessary.

as

TODO think about the definition a bit more.

/my_cue/play
/my_cue/trig chorus (trig named action)
/my_cue/trig break
/my_cue/next (trig next action)
/my_cue/fade 10
/my_cue/param/1 0.3

- player logic
- audio mixer
- macro parameters


*/

SynthTracker
asArgsArray

(
//Fade + stop
fork {
	var g, t, p, b, z;
	//Cue plays in group
	g = Group();
	b = Bus.audio(s, 2);
	//Has its own clock
	t = TempoClock.new;
	//

	z = { Out.ar(0, In.ar(b, 2) * Env.cutoff(1).ar(0, \gate.kr(1)) ) }.play(g);

	p = Pspawner({ |sp|
		sp.seq(Pbind(\out, b, \group, g, \dur, Pwhite(0.01, 0.02)));
	}).play(t);

	1.wait;
	//bind to avoid node not found msgs
	z.release(10);
	10.wait;
	s.bind {
		t.clear;
		p.stop;
		g.free;
	}
}
)


