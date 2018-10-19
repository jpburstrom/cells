//A player for players
//By default, ~player is an environment with functions
//Player functions can be redefined by using ~playerFunc
//to define actions.
//As a shortcut, you can also set ~player to be a function, like this:
/*
p.player_({
	var synth, buf;

	//All objects attached to environment variables will be freed after stop
	~buf = Buffer.read(s, "/Users/johannes/lovestory.wav");

	//We run the function on load, in a routine, so we can use sync etc
	s.sync;

	//The above can also be put in a ~load function.

	//Redefined play action. The player itself will take care of all complex
	//player logic, so we just write what we want to do. It's run in a private environment,
	//but you can reach the player controller as an function argument:
	~play = { |player|
		synth = {
			PlayBuf.ar(2, ~buf)
		}.play;
		~buf.postln;
		player.stop;
	};

	//Stop action. if you want to
	~stop = { |player|
		player.waitFor(~synth.release(10).onFree(_).inEnvir)
	};

}).play

*/

p = Proto {

	~cond = Condition(false);
	~playerCond = Condition(false);

	~playAfterLoad = false;

	~stateNum = 1;
	~states = IdentityDictionary[
		\stopped -> 1,
		\loading -> 2,
		\ready -> 4,
		\playing -> 8,
		\paused -> 16,
		\stopping -> 32,
		\waiting -> 64,
		\error -> 128
	];

	~player = Environment();

	~playerFunc = {

		~load = { |ev| \load.postln; 3.wait };

		~beforePlay = {\beforePlay.postln; 1.wait};

		~play = {\play.postln};

		~afterPlay = {\afterPlay.postln};

		~beforeStop = { \beforeStop.postln; 3.wait;  };

		~stop = {\stop.postln};

		~afterStop = {\afterStop.postln};

		~pause = {\pause.postln};

		~resume = {\resume.postln};

		~freeAll = {
			var ev = currentEnvironment;
			ev.tryPerform(\freeAll) ?? {

				ev.tryPerform(\deepDo, 99, {|x| x.free})
			} ?? {
				ev.do(_.postln)
			};
		};

	};


	~playerWaitFor = { |...keys|
		try {
			keys.do { |key|
				~playerCond.test = false;
				"into %".format(key).debug;
				fork {
					(~player[key] !? (_.inEnvir(~player))).value(currentEnvironment);
					"out of %".format(key).debug;
					~playerCond.test = true;
					~playerCond.signal;
				};
				~playerCond.wait;
				"truly out of %".format(key).debug;

			}
		} { |err|
			err.reportError;
			false
		}
			Error
	};

	~waitFor = { |func|
		var cond = Condition();
		fork {
			func.value({ cond.unhang });
		};
		cond.hang;
	};

	~makePlayer = {
		if (~player.isFunction) {
			~playerFunc = ~player;
			~player = ();
		};
		~playerFunc !? {
			~player.make(~playerFunc);
		}
	};

	~load = {
		~cond.test = false;
		fork {
			CmdPeriod.doOnce(currentEnvironment);
			if (~prCheckState.(\stopped, \error)) {
				~prChangeState.(\loading);
				~makePlayer.value;
				~playerWaitFor.(\load);
				if (~prCheckState.(\stopping).not) {
					~prChangeState.(\ready);
					if (~playAfterLoad) {
						~playAfterLoad = false;
						~play.value;
					};
				}
			};
			~cond.test = true;
			~cond.signal;
		};
		currentEnvironment
	};

	~play = {
		~cond.test = false;
		fork {
			switch(~stateNum,
				~states[\stopped], { ~playAfterLoad = true; ~load.value; },
				~states[\loading], { ~playAfterLoad = true; },
				~states[\ready], {
					~playerWaitFor.(\beforePlay, \play);
					if (~prCheckState.(\stopping).not) {
						~prChangeState.(\playing);
						~playerWaitFor.(\afterPlay);
					};
				},
				~states[\paused], { ~resume.value }
			);
			~cond.test = true;
			~cond.signal;
		};
		currentEnvironment
	};

	~stop = {
		fork {
			if (~prCheckState.(\stopped, \stopping).not) {
				~prChangeState.(\stopping);
				~playerCond.wait;
				~playerWaitFor.(\beforeStop);
				~playerWaitFor.(\stop);
				~prChangeState.(\stopped);
				~playerWaitFor.(\afterStop);
				~playerWaitFor.(\freeAll);
				//TODO: reset state
				~playAfterLoad = false;
				CmdPeriod.remove(currentEnvironment);
			};
			~cond.test = true;
			~cond.signal;
		};
		currentEnvironment
	};

	~pause = {
		currentEnvironment
	};

	~resume = {
		currentEnvironment
	};

	~then = { |func|
		forkIfNeeded {
			~cond.wait;
			func.value;
		}
	};

	~wait = {
		~cond.wait
	};

	~state = { ~states.findKeyForValue(~stateNum) };

    ~isStopped = { ~prCheckState.(\stopped) };
    ~isLoading = { ~prCheckState.(\loading) };
    ~isReady = { ~prCheckState.(\ready) };
    ~isPlaying = { ~prCheckState.(\playing) };
    ~isPaused = { ~prCheckState.(\paused) };

    ~prChangeState = { arg st;
		st.debug("state");
        ~stateNum = ~states[st];
			this.changed(\state);
    };

    ~prCheckState = { arg ... st;
		(st.collect(~states[_]).sum & ~stateNum) == ~stateNum;
    };


	~cmdPeriod = {
		fork {
			if (~prCheckState.(\stopped).not) {
				~prChangeState.(\stopped);
				~playerWaitFor.(\afterStop);
				~playerWaitFor.(\freeAll);
			}
		}
	};

	// ~proto <> { ~play = { "redefine play".postln } }
	currentEnvironment['<>'] = { |func|
		if (func.isFunction) {
			var out = currentEnvironment.clone;
			out.make {
				if (~player.isFunction) {
					~player = func <> ~player;
				} {
					~playerFunc = func;
				}
			};
		} {
			"Not a function".warn;
		}
	}

};
