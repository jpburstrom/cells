Cell : EnvironmentRedirect {

	classvar states;
	classvar <parentEnvironment;
	classvar <>debug=false;

	//Cue name (for display purposes)
	var <>name;
	var <cond, playerCond;
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

		StartUp.add({
			this.loadParentEnvironment;
		});

	}

	*loadParentEnvironment {

		(PathName(this.filenameSymbol.asString).pathOnly +/+ "lib/synthDefs.scd").loadPath;
		parentEnvironment = (PathName(this.filenameSymbol.asString).pathOnly +/+ "lib/parentEnvironment.scd").loadPath;

	}

	*addPlayer { |key, envirOrFunc, basePlayerKey ...mixinKeys|

		var env = Environment.make {
			mixinKeys.do { |key|
				parentEnvironment[\mixins][key].value;
			};

			basePlayerKey !? {
				currentEnvironment.putAll(
					parentEnvironment[\players][basePlayerKey].deepCopy,

				)
			};
		};

		if (envirOrFunc.respondsTo(\keysValuesDo)) {
			env.putAll(envirOrFunc);
		} {
			// Assume function
			env.make(envirOrFunc)
		};

		parentEnvironment[\players][key] = env;

	}

	*removePlayer { |key|
		parentEnvironment[\players][key] = nil;
	}

	*new { |func, playerKey, know=true|
		^super.new.init(func, playerKey, know);
	}

	init { |func, playerKey, knowFlag|

		cond = Condition(true);
		playerCond = Condition(true);
		children = Set();
		playAfterLoad = false;
		stateNum = states[\free];
		name = "";

		envir.know = knowFlag;

		envir.parent = parentEnvironment[\players][playerKey];
		if (envir.parent.isNil) {
			envir.parent = parentEnvironment[\players][\basic];
		};

		// Copy some keys (eg settings, templates) to proto, to not overwrite the
		// class-level dictionary
		envir.parent[\copyToProto].do { |key|
			envir.proto[key] = envir.parent[key].deepCopy;
		};

		// The make function is run inside the proto of the environment
		// that way, user data and temporary objects are kept separate from objects
		// created during init
		// EnvironmentRedirect.new have made the proto for us
		envir.proto.make {

			// Call func for custom behaviour
			// It should be possible to do this without passing this or parent to function
			// Otherwise there's a risk of modifying the class-level parent dict
			// But otoh every other function (init, play etc) can potentially
			// change things in the parent.
			// TODO think about when to pass this and not
			func.value;

			// Set params from paramTemplate
			~params = ~params ?? { IdentityDictionary().know_(true) };
			// Param template has functions as value
			// So we call .value on each one to init params
			envir[\paramTemplate] !? { |tmpl|
				tmpl.keysValuesDo { |k, func|
				// Don't overwrite existing params (set in func)
					~params[k] = ~params[k] ?? func;
				}
			};

		};


		this.use {
			envir[\beforeInit].value(this);
			envir[\init].value(this);
			envir[\afterInit].value(this);
		};

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
				protect {
					this.use {
						envir[key].value(this);
					};
				} { |err|
					if (err.notNil) {
						this.prChangeState(\error);
						playerCond.test = true;
						playerCond.signal;
					};
				};
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
		CmdPeriod.doOnce(this);
		cond.test = false;
		forkIfNeeded {
			if (this.checkState(\stopped, \error, \free)) {
				this.prChangeState(\loading);
				this.trigAndWait(\beforeLoad, \load, \afterLoad);
				if (this.checkState(\stopping, \error).not) {
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
					this.trigAndWait(\beforePlay, \play, \afterPlay);
					if (this.checkState(\stopping).not) {
						this.prChangeState(\playing);
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
					this.trigAndWait(\beforeHardStop, \hardStop, \afterHardStop);
				} {
					this.trigAndWait(\beforeStop, \stop, \afterStop);
				};
				this.afterStop;
				if (now) {
					this.freeAll;
				};

			};
			cond.test = true;
			cond.signal;
		};
	}

	afterStop {
		if (this.checkState(\stopped, \free).not) {
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
				this.use(envir[\freeAll]);
			} {
				envir.tryPerform(\deepDo, 99, { |x|
					//Don't free symbols, please
					if (x.isSymbol.not) { x.free }
				})
			};
			this.use(envir[\afterFree]);
			this.prChangeState(\free);
		};

	}

	free {
		this.children.do { |child|
			child.free;
			child.unsetMother;
		};
		this.children.clear;
		if (this.checkState(\stopping, \stopped, \free, \error).not) {
			forkIfNeeded {
				this.stop(true);
				this.freeAll;
			}
		} {
			this.freeAll;
		};
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

	isStopped { ^this.checkState(\stopped) }
	isLoading { ^this.checkState(\loading) }
	isReady { ^this.checkState(\ready) }
	isPlaying { ^this.checkState(\playing) }
	isPaused { ^this.checkState(\paused) }

	prChangeState { |state|
		stateNum = states[state];
		this.changed(\state, state);
		this.changed(state);
	}

	//Check if state equals one of the supplied symbols
	checkState { |... sts|
		^(sts.collect(states[_]).reject(_.isNil).sum & stateNum) == stateNum;
	}

	cmdPeriod {
		// I'm leaving this here, as a safety thing
		// If error occurs, we at least would like to reset the state
		// There might be a possible race condition,
		// but it seems that in the normal case,
		// state == \free already
		if (this.checkState.(\stopped, \free).not) {
			this.freeAll;
		}
	}



	addChildren { |...keys|
		var child;
		keys.do { |key|
			child = envir[key];
			if (this.validateRelative(child)) {
				children.add(child);
				child.setMother(this);
			} {
				"Not a valid child".warn;
			}
		};
	}

	removeChildren { |...keys|
		var child;
		keys.do { |key|
			child = envir[key];
			children.remove(child);
			if (child.mother == this) {
				child.unsetMother;
			};
		};
	}

	// Set mother
	// if childKey is provided,
	// set this as children of mother
	// under key childKey
	setMother { |obj, childKey|
		if (this.validateRelative(obj)) {
			mother = obj;
			if (childKey.notNil) {
				obj[childKey] = this;
				obj.addChildren(childKey)
			}
		} {
			"Not a valid mother".warn;
		}
	}

	unsetMother {
		mother = nil;
	}

	//Chek if an object could be a valid child/mother
	validateRelative { |other|
		^other.isKindOf(this.class)
	}

	siblings {
		^mother !? {
			mother.children.reject(this);
		};
	}

	doFunctionPerform { arg selector, args;
		envir[\forward] !? {
			if(envir[selector].isNil) {
				// This is different: We call function within envir
				^this.use {
					envir[\forward].functionPerformList(\value, selector, args)
				};
			}
		};
		// This is different: We call function within envir
		^this.use { this[selector].functionPerformList(\value, args) };
	}


	printOn { arg stream; stream << this.class.name << "(" <<< name <<")" }
}
