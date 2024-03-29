Cell : EnvironmentRedirect {

	classvar states,
	// An environment where templates are made
	<templateEnvironment,
	// The actual templates
	<templates;
	classvar <>debug=false;

	//Cue name (for display purposes)
	var <>name;
	var <argPairs, playerType;
	var <cond, playerCond;
	var <playAfterLoad;
	var <clock;
	var <>syncClock, <>syncQuant;
	var stateNum;
	var snapshotPath;

	*initClass {
		states = IdentityDictionary[
			\stopped -> 1,
			\loading -> 2,
			\ready -> 4,
			\playing -> 8,
			\paused -> 16,
			\stopping -> 32,
			\free -> 64,
			\waitForPlay -> 128,
			\error -> 256
		];

		templateEnvironment = Environment();
		templates = IdentityDictionary();

		StartUp.add({
			this.loadTemplates;
		});

	}

	*loadTemplates {
		templateEnvironment.clear;
		templates.clear;
		(PathName(this.filenameSymbol.asString).pathOnly +/+ "lib/synthDefs.scd").loadPaths;
		(PathName(this.filenameSymbol.asString).pathOnly +/+ "lib/templates.scd").loadPaths;

	}

	*addTemplate { |key, func, deps|
		templateEnvironment.make {
			currentEnvironment[key] = CellTemplate(func, deps);
			templates[key] = currentEnvironment[key].value;
		};
	}

	*removeTemplate { |key|
		templates[key] = nil;
	}

	*help { |...keys|
		if (keys.isEmpty) {
			keys = templates.keys.asArray.sort;
		};
		keys.do { |k|
			var v = templates[k];
			"% (%)".format(k, templateEnvironment[k].dependencies.asArray.join(", ")).underlined.postln;
			v[\templateDescription].postln;
			"".postln;
		}
	}

	*new { |templateKey ... pairs|
		^super.new.init(templateKey, pairs);
	}

	*doesNotUnderstand { |selector ... args|
		// Syntax sugar for creating an instance with a specific template
		if (templates[selector].notNil) {
			^this.new(selector, *args)
		} {
			^this.superPerformList(\doesNotUnderstand, selector, args);
		}
	}

	init { |templateKey, pairs|

		cond = Condition(true);
		playerCond = Condition(true);
		syncQuant = { this.getQuant ? 0 };
		syncClock = TempoClock.default;
		playAfterLoad = false;
		stateNum = states[\free];

		playerType = templateKey;

		name = "";

		envir.know = true;

		envir.parent = templates[templateKey];
		if (envir.parent.isNil) {
			if (templateKey.notNil) {
				"Cell player % not found".format(templateKey).warn;
			};
			playerType = \base;
			envir.parent = templates[playerType];
		};

		// Copy some keys (eg settings, templates) to proto, to not overwrite the
		// class-level dictionary
		envir.parent[\templateInstanceData].keysValuesDo { |key, data|
			envir.proto[key] = data.deepCopy;
		};

		pairs = pairs.asList;
		this.use { ~templateValidateArgs.value(pairs) };

		if (pairs.size.odd) {
			Error("The cell doesn't have even number of arguments after template validation.").throw
		};
		argPairs = pairs.asArray;

		// The make function is run inside the proto of the environment
		// that way, user data and temporary objects are kept separate from objects
		// created during init
		// parent ->
		// EnvironmentRedirect.new have made the proto for us
		argPairs.pairsDo { |k, v|
			if (envir.proto[k].respondsTo(\keysValuesDo)) {
				v = envir.use { v.value };
				if (v.isKindOf(IdentityDictionary)) {
					envir.proto[k] = this.mergeDict(envir.proto[k], v)
				} {
					Error("%: Wrong type. Needs to return an IdentityDictionary on .value. Was %.".format(k, v.class)).throw;
				}
			} {
				envir.proto[k] = v;
			}
		};


		this.proto.use {
			envir[\templateInit].value(this);
			envir[\init].value(this);
			envir[\afterInit].value(this);
		};

		//Init might create resources. We need to change state to be able to free them.
		this.prChangeState(\stopped);

	}

	help {
		this.class.help(playerType)
	}

	mergeDict { |template, obj|
		obj.keysValuesDo { |k, v|
			if (template[k].isNil) {
				template[k] = v;
			} {
				if (template[k].isKindOf(Dictionary) and: { v.isKindOf(Dictionary) } ) {
					this.mergeDict(template[k], v)
				} {
					// Overwrite single values
					template[k] = v;
				}
			};
		};
		^template
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

	load { |ffwd, argQuant, argClock|
		if (this.checkState(\stopped, \error, \free)) {
			cond.test = false;
			envir[\fastForward] = ffwd ? envir[\fastForward] ? 0;
			this.prChangeState(\loading);
			forkIfNeeded {
				this.trigAndWait(\templateLoad, \load, \templatePostLoad);

				if (envir[\fastForward].isNegative) {
					//TODO: This is a fallback,
					//Usually player templates take care of converting negative ffwd values,
					//but it's currently spread out in the player code. Find a
					//way to do this only once, but still adjust play starts according
					//to each player's needs
					var ffwd = envir.settings[\duration] + envir[\fastForward];
					if (ffwd == inf) { ffwd = 0 };
					envir[\fastForward] = ffwd;
				};
				// Play time in seconds (absolute)
				// LATER: make sure we have an envir with settings ready so we don't need the nil check
				clock = TempoClock((envir[\settings][\tempo] ? 60) / 60);
				if (this.checkState(\error).not) {
					this.prChangeState(\ready);
				};
				if (this.checkState(\stopping).not) {
					if (playAfterLoad) {
						playAfterLoad = false;
						this.play(ffwd, argQuant, argClock);
					} {
						cond.test = true;
						cond.signal;
					}
				}
			};
		};
	}

	play { |ffwd, argQuant, argClock|
		argQuant = argQuant ?? syncQuant;
		argClock = argClock ?? syncClock;
		if (this.isReady and: { ffwd.notNil } and: { ffwd != envir[\fastForward] }) {
			this.stop(true).then {
				this.play(ffwd, argQuant, argClock);
			}
		};
		switch(stateNum,
			states[\stopped], { playAfterLoad = true;  this.load(ffwd, argQuant, argClock) },
			states[\free], { playAfterLoad = true; this.load(ffwd, argQuant, argClock) },
			states[\loading], { playAfterLoad = true },
			states[\paused], { this.resume; cond.test = true; cond.signal },
			states[\ready], {
				cond.test = false;
				//Set beats to sync 0 with syncClock's next beat according to syncQuant.
				//timeToNextBeat is in seconds, so multiply with this clock's tempo.
				forkIfNeeded {

					this.prChangeState(\waitForPlay);

					this.trigAndWait(\templatePreparePlay);
					this.prChangeState(\playing);

					//Here we set the beats to a possibly negative value adjusted for quant
					clock.beats = (envir[\fastForward] -
						(argClock.timeToNextBeat(argQuant) /
							argClock.tempo)) * clock.tempo;

					//Schedule play starting at clock time 0
					clock.schedAbs(envir[\fastForward] * clock.tempo, {
						fork {
							this.trigAndWait(\templatePlay, \play);
							cond.test = true;
							cond.signal;
						}
					})
				}
			}
		);
	}

	spawn { |ffwd, argQuant, argClock|
		^this.copy.play(ffwd, argQuant, argClock);
	}

	stop { |now=false|
		if ((this.checkState(\stopping) && (now == true)) || this.checkState(\stopped, \free).not) {
			cond.test = false;
			this.prChangeState(\stopping, true);
			playAfterLoad = false;
			forkIfNeeded {
				//Loading is done in several steps, so we need a while here
				while { this.checkState(\loading, \waitForPlay) } {
					playerCond.wait; //If currently loading, wait until done before cleaning up
				};
				this.prChangeState(\stopping);
				if (now == true) {
					clock.stop;
					this.use {
						#[templateStop, stop, templatePostStop].do { |key|
							fork { envir[key].value(this) };
						}
					};
				} {
					this.trigAndWait(\templateStop, \stop, \templatePostStop);
				};
				this.prChangeState(\stopped);
				envir[\fastForward] = 0; //TEMP reset, later clear the entire envir
				cond.test = true;
				cond.signal;
			};
		};
	}

	pause {
		this.notYetImplemented;
	}

	resume {
		this.notYetImplemented;
	}

	free {
		if (this.checkState(\free).not) {
			this.stop(true).then {
				this.use(envir[\templateFree]);
				this.use(envir[\free]);
				this.prChangeState(\free);
			}
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

	prChangeState { |state, or=false|
		if (or) {
			stateNum = stateNum | states[state];
		} {
			stateNum = states[state];
		};
		this.changed(\state, state);
		this.changed(state);
	}

	//Check if state equals one of the supplied symbols
	checkState { |... sts|
		^sts.any( { |sym|
			((states[sym] ? 0) & stateNum) == states[sym]
		});
	}

	// Round seconds to closest quantized beat
	// Haven't found a way to do this on clock,
	// so this is mostly borrowed from TempoClock:nextTimeOnGrid
	roundToQuant { |seconds|
		var phase, quant = this.getQuant;
		phase = (quant.phase ? 0) - (quant.timingOffset ? 0);
		quant = quant.quant;


		if (quant == 0) { ^seconds + phase };
		if (quant < 0) { quant = clock.beatsPerBar * quant.neg };
		if (phase < 0) { phase = phase % quant };

		seconds = syncClock.secs2beats(seconds);

		^syncClock.beats2secs(
			roundUp(seconds - syncClock.baseBarBeat - (phase % quant), quant)
			+ syncClock.baseBarBeat + phase
		);
	}

	// Time (in seconds) to position, relative to this clock
	// Offset: An offset in seconds. Positive offset = later.
	// quantSync: if true, quantize time to closest beat as defined in ~settings[\quant].
	// Offset is added before quant, subject to change.
	timeToPos { |cue, offset=0, quantSync=false|
		^clock !? {
			var playPos,
			cueTime = case(
				{ cue == \playStart }, { 0 },
				{ cue == \playEnd }, { this.settings[\duration] },
				{ cue.isKindOf(Symbol) }, {
					cue = this.getMarkerTime(cue);
				},
				{ cue.isNumber }, { cue }
			);

			if (this.checkState(\playing, \waitForPlay)) {
				playPos = clock.seconds;
			} {
				playPos = clock.beats2secs((envir[\fastForward] ? 0) * clock.tempo);
			};

			cueTime !? {
				//Set cueTime to seconds relative to cue start
				//(ignore ffwd)
				cueTime = clock.beats2secs(0) + cueTime;


				//Sync with quant
				if (quantSync) {
					cueTime = this.roundToQuant(cueTime);
					//If cueTime is close, the rounding might make us
					//end up with a time in the past,
					//In that case, go with next beat instead
					if (cueTime < clock.seconds) {
						cueTime = this.clock.beats2secs(this.getQuant.nextTimeOnGrid(clock));
					};
				};
				cueTime - playPos + offset;
			};
		}
	}

	waitForPos { |cue, offset=0, quantSync=false|
		var time = this.timeToPos(cue, offset, quantSync);
		var tempo = thisThread.clock.tryPerform(\tempo) ? 1;
		if (time.notNil) {
			time = time * tempo;
			if (this.class.debug) {
				time.debug("Wait for position");
			};
			time.wait;
		};
		^time
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

	copy {
		^Cell.new(playerType, *argPairs);
	}

	clone { |templateKey ... pairs|

		var old = argPairs.asDict;
		var new = pairs.asDict;
		pairs = old.putAll(new).asPairs;

		if (templateKey.isNil) {
			templateKey = playerType
		};

		^this.class.new(templateKey, *pairs);
	}

	printOn { arg stream; stream << this.class.name << "(" <<< name <<")" }

	update { |obj, what ...args|
		^envir.use({
			~update.value(obj, what, *args)
		})
	}

	asStream {
		^Routine({ |inval|
			loop {
				inval = envir.yield
			}
		}.inEnvir)
	}

	getSnapshot { |func|
		var out = IdentityDictionary();
		var getSnap = this[\getSnapshot];
		var count = getSnap.size;
		//Function has count == 0, CellFunctionList should have count > 0
		//If getSnapshot is anything else, return it directly
		//this might be stupid
		if (getSnap.isFunction.not and: { count == 0 }) {
			^func.(this[\getSnapshot])
		};
		this.use {
			~getSnapshot.value({ |snap|
				out.putAll(snap);
				count = count - 1;
				count.postln;
				if (count <= 0) {
					func.value(out);
				}
			})
		}
	}

	setSnapshot { |snapshot|
		this.use { this[\setSnapshot].value(snapshot) }
	}
}