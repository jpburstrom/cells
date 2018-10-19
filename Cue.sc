Cue {

	classvar states;

	var <cond, <playerCond;
	var <mother, <children;
	var <playAfterLoad;
	var stateNum;
	var <player, <playerFunc;

	*initClass {
		states = IdentityDictionary[
			\stopped -> 1,
			\loading -> 2,
			\ready -> 4,
			\playing -> 8,
			\paused -> 16,
			\stopping -> 32,
			\free -> 64,
			\error -> 128
		];
	}

	*new { |func|
		^super.new.init(func);
	}

	init { |func|

		cond = Condition(false);
		playerCond = Condition(false);
		children = Set();
		playAfterLoad = false;
		stateNum = states[\free];

		//Initialize player
		player = Environment();
		playerFunc = func; //TODO addFunc dance
		this.initPlayer;

	}


	initPlayer {
		player.make(playerFunc)
	}

	//Run specific trigger(s) in player, eg play, stop etc.
	//Should be run within a routine
	trigAndWait { |...keys|

		keys.do { |key|
			playerCond.test = false;
			// "into %".format(key).debug;
			fork {
				(player[key] !? (_.inEnvir(player))).value(this, playerCond);
				// "out of %".format(key).debug;
				playerCond.test = true;
				playerCond.signal;
			};
			playerCond.wait;
			// "truly out of %".format(key).debug;

		}

	}

	//Func receives callback as argument, which is called
	//when func has finished doing what it should do
	//eg. this.waitFor({ |c| s.sync; c.value })
	//TODO: maybe accept number (delay) and condition as well?
	//Currently unused?
	waitFor { |func|
		var cond = Condition();
		fork {
			func.value({ cond.unhang });
		};
		cond.hang;
	}

	//Get something from player envir
	get { |what|
		if (player.isEmpty) {
			this.initPlayer;
		};
		player[what];
	}

	//Set something in player envir
	set { |what, val|
		//Set both factory function and current player envir
		playerFunc.addFunc { currentEnvironment[what] = val };
		player[what] = val;
	}

	load {
		cond.test = false;
		forkIfNeeded {
			if (this.checkState(\stopped, \error, \free)) {
				this.prChangeState(\loading);
				this.initPlayer;
				//TODO: how is server(s) defined?
				(player[\server] ?? { Server.default }).do(ServerTree.remove(currentEnvironment, _));
				this.trigAndWait(\load);
				if (this.checkState(\stopping).not) {
					this.prChangeState(\ready);
					if (playAfterLoad) {
						playAfterLoad = false;
						this.play;
					};
				}
			};
			cond.test = true;
			cond.signal;
		};
	}

	play {
		cond.test = false;
		forkIfNeeded {
			switch(stateNum,
				states[\stopped], { playAfterLoad = true; this.load },
				states[\free], { playAfterLoad = true; this.load },
				states[\loading], { playAfterLoad = true; },
				states[\ready], {
					this.trigAndWait(\beforePlay, \play);
					if (this.checkState(\stopping).not) {
						this.prChangeState(\playing);
						this.trigAndWait(\afterPlay);
					};
				},
				states[\paused], { this.resume }
			);
			cond.test = true;
			cond.signal;
		};
	}

	stop {
		//FIXME: server variable, hardcoded fallback
		cond.test = false;
		forkIfNeeded {

			if (this.checkState(\stopped, \stopping).not) {
				this.prChangeState(\stopping);
				playerCond.wait; //Wait until playing trigs have finished before cleaning up
				this.trigAndWait(\beforeStop);
				this.trigAndWait(\stop);
				this.prChangeState(\stopped);
				this.trigAndWait(\afterStop);
				this.hardStop;
			};
			cond.test = true;
			cond.signal;
		};
	}

	hardStop {
		if (this.checkState(\stopped).not) {
			(player[\server] ?? { Server.default }).do(ServerTree.remove(currentEnvironment, _));
			this.prChangeState(\stopped);
			this.freeAll;
		};
	}

	pause {
		this.notYetImplemented;
	}

	resume {
		this.notYetImplemented;
	}

	freeAll { |completely=false|
		var func = {
			if (this.checkState(\stopped).not) {
				this.hardStop;
			} {
				//Ok, we have stopped, let's free stuff
				if (this.checkState(\free).not) {
					//If player has a freeAll function, use that.
					//Otherwise just brutally free everything player has, recursively.
					if (player[\freeAll].notNil) {
						player.use(player[\freeAll]);
					} {
						player.tryPerform(\deepDo, 99, { |x|
						//Don't free symbols, please
							if (x.isSymbol.not) { x.free }
						})
					};
					this.prChangeState(\free);
				};
			}
		};
		//Completely = remove everything, clear player environment
		if (completely) {
			//Need to remove this before forking, to avoid race conditions
			(player[\server] ?? { Server.default }).do(ServerTree.remove(currentEnvironment, _));
			forkIfNeeded {
				func.value;
				player.use(player[\free]);
			}
		} {
			func.value;
		}
	}

	//Wait for cond (in case we're currently triggering an action)
	//and then call function
	then { |func|
		forkIfNeeded {
			cond.wait;
			func.value(this);
		}
	}

	//Just wait, if needed
	wait {
		cond.wait;
	}

	//Current state as symbol
	state {
		^states.findKeyForValue(stateNum)
	}

	isStopped { this.checkState(\stopped) }
	isLoading { this.checkState(\loading) }
	isReady { this.checkState(\ready) }
	isPlaying { this.checkState(\playing) }
	isPaused { this.checkState(\paused) }

	prChangeState { |state|
		stateNum = states[state];
		this.changed(\state, state);
		this.changed(state);
	}

	//Check if state equals one of the supplied symbols
	checkState { |... sts|
		^(sts.collect(states[_]).sum & stateNum) == stateNum;
	}

	//TODO: serverTree only works with server, of course.
	//We need to implement cmdPeriod for non-audio cues
	doOnServerTree {
		//TODO: find a good way of not hardcoding this stuff
		player.synth = nil;
		player.synths.clear;
		//^ this stuff
		if (this.checkState.(\stopped, \free).not) {
			this.hardStop;
		}

	}

	free {
		this.stop;
		//TODO: clear environment
	}


	addChildren { |...children|
		children.flat.do { |child|
			if (this.validateRelative(child)) {
				children.add(child);
				child.setMother(this);
			} {
				"Not a valid child".warn;
			}
		};
	}

	setMother { |obj|
		if (this.validateRelative(obj)) {
			mother = obj;
			if (obj.children.includes(currentEnvironment).not) {
				obj.addChildren(currentEnvironment)
			}
		} {
			"Not a valid mother".warn;
		}
	}

	//Chek if an object could be a valid child/mother
	validateRelative { |other|
		^other.isKindOf(this.class)
	}

	siblings {
		^mother !? {
			mother.children.reject(currentEnvironment);
		};
	}

	<> { |func|
		if (func.isFunction or: func.isKindOf(FunctionList)) {
			~playerFunc = ~playerFunc.addFunc(func);
		} {
			//Ignore nil
			func !? {
				"Not a function".warn;
			}
		};
	}


}