Cell : EnvironmentRedirect {

	classvar states;
	classvar debug=false;

	var <cond, <playerCond;
	var <mother, <children;
	var <playAfterLoad;
	var stateNum;

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

	*new { |func, env|
		^super.new(env).init(func);
	}

	init { |func|

		cond = Condition(false);
		playerCond = Condition(false);
		children = Set();
		playAfterLoad = false;
		stateNum = states[\free];

		envir.make(func);

	}

	//Run specific trigger(s) in envir, eg play, stop etc.
	//Should be run within a routine
	//Private
	trigAndWait { |...keys|

		keys.do { |key|
			playerCond.test = false;
			if (debug) {
				"into %".format(key).debug;
			};
			fork {
				(envir[key] !? (_.inEnvir(envir))).value(this, playerCond);
				if (debug) {
					"out of %".format(key).debug;
				};
				playerCond.test = true;
				playerCond.signal;
			};
			playerCond.wait;
			// "truly out of %".format(key).debug;

		}

	}

	load {
		cond.test = false;
		forkIfNeeded {
			if (this.checkState(\stopped, \error, \free)) {
				this.prChangeState(\loading);
				this.initPlayer;
				//TODO: how is server(s) defined?
				(envir[\server] ?? { Server.default }).do(ServerTree.remove(currentEnvironment, _));
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

	stop { |now=false|
		cond.test = false;
		forkIfNeeded {

			if (this.checkState(\stopped, \stopping).not) {
				this.prChangeState(\stopping);
				playerCond.wait; //If currently loading, wait until done before cleaning up
				if (now and: envir[\hardStop].notNil) {
					this.trigAndWait(\hardStop);
				} {
					this.trigAndWait(\stop);
				};
				this.afterStop;
				this.freeAll;
			};
			cond.test = true;
			cond.signal;
		};
	}

	afterStop {
		if (this.checkState(\stopped, \free).not) {
			(envir[\server] ?? { Server.default }).do(ServerTree.remove(currentEnvironment, _));
			this.prChangeState(\stopped);
		};
	}

	pause {
		this.notYetImplemented;
	}

	resume {
		this.notYetImplemented;
	}

	freeAll {
		if (this.checkState(\free).not) {
			//If envir has a freeAll function, use that.
			//Otherwise just brutally free everything envir has, recursively.
			if (envir[\freeAll].notNil) {
				envir.use(envir[\freeAll]);
			} {
				envir.tryPerform(\deepDo, 99, { |x|
					//Don't free symbols, please
					if (x.isSymbol.not) { x.free }
				})
			};
			this.prChangeState(\free);
		};

	}

	// Since stop is calling free
	free {
		if (this.checkState(\stopping, \stopped, \free, \error).not) {
			this.stop(true);
		};
		this.freeAll;
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
		^(sts.collect(states[_]).reject(_.isNil).sum & stateNum) == stateNum;
	}

	//TODO: serverTree only works with server, of course.
	//We need to implement cmdPeriod for non-audio cues
	doOnServerTree {
		//TODO: find a good way of not hardcoding this stuff
		envir.synth = nil;
		envir.synths.clear;
		//^ this stuff
		if (this.checkState.(\stopped, \free).not) {
			this.afterStop;
			this.freeAll;
		}
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

	//Copied verbatim from EnvironmentRedirect. Why?
	doFunctionPerform { arg selector, args;
		envir[\forward] !? {
			if(envir[selector].isNil) {
				^envir[\forward].functionPerformList(\value, this, selector, args);
			}
		};
		^this[selector].functionPerformList(\value, this, args);
	}


}
