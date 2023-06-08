Cell.addTemplate(\initData, {
	~build = {
		~instanceData = IdentityDictionary().know_(true); //Instance-level data
	};

	~templateInit = { |cell|
		~getCell = {
			cell;
		}
	};

	~addInstanceData = { |key, value|
		~instanceData[key] = value;
	}
});

Cell.addTemplate(\markers, {

	~build = {
		//This is created in ~cell, but we refer to it as ~markers since
		//functions are running in instance
		~addInstanceData.(\markers, IdentityDictionary());
	};

	~markerParser = {
		(
			state: \default,
			out: (loops: ()),
			run: { |ev, line|
				ev[ev.state].value(ev, line);
			},
			reset: { |ev|
				ev.out.clear;
				ev.state = \default;
			},
			default: { |ev, line|
				var sub = line.split(Char.space)[0].toLower.asSymbol;
				if ([\smpl, \cue, \list].includesEqual(sub)) {
					ev.state = sub;
				};
			},
			getSubData: { |ev, line|
				line.split($:).collect(_.trim)
			},
			//Check sub command
			cue: { |ev, line|
				var data = ev.getSubData(line);
				if (data[0] == "Count") {
					ev.out[\count] = data[1].asInt;
					ev.out[\pos] = Array(ev.out[\count]);
					ev.out[\lbl] = nil ! ev.out[\count];
					ev.state = \marker;
				};
			},
			marker: { |ev, line|
				if (line[0].isSpace) {
					line.trim.findRegexp("[^:]+:\\s+\\S+\\s+").do { |item|
						var thing = item[1].split($:).collect(_.trim);
						if (thing[0] == "Pos") {
							ev.out.pos.add(thing[1].asInteger);
						};
					}
					// line.split(Char.space).postcs;
				} {
					ev.state = \default;
					ev[ev.state].value(ev, line);
				}
			},
			smpl: { |ev, line|
				var data = ev.getSubData(line);
				if (data[0] == "Loop Count") {
					ev.out[\loopCount] = data[1].asInt;
					ev.state = \loop;
				};
			},
			loop: { |ev, line|
				if (line[0].isSpace) {
					var loop = ();
					line.trim.findRegexp("[^:]+:\\s+\\S+\\s+").do { |item|
						var thing = item[1].split($:).collect(_.trim);
						if (thing[0] == "Cue ID") {
							ev.out.loops[thing[1].asInteger - 1] = loop;
						} {
							loop[thing[0].toLower.asSymbol] = thing[1];
						}
					}
					// line.split(Char.space).postcs;
				} {
					ev.state = \default;
					ev[ev.state].value(ev, line);
				}
			},
			list: { |ev, line|
				var data = ev.getSubData(line);
				if (data[0] == "labl") {
					ev.out.lbl[data[1].asInt - 1] = data[2].asSymbol;
				};
			},

			getMarkers: { |ev, offset|
				var loopKeys = ev.out.loops.keys;
				//FIXME This might cause negative positions. is that ok?
				if (ev.out.pos.notNil) {
					[ev.out.lbl, ev.out.pos - (offset ? 0)].flop
					.reject({ |v, i| loopKeys.includes(i) })
					.flat
					.asDict
				}
			},

			getRegions: { |ev|
				var out = IdentityDictionary();
				ev.out.loops.keysValuesDo { |index, v|
					var name = ev.out.lbl[index];
					out[name] = [v.start.asInteger, v.end.asInteger]
				};
				out
			},

			parse: { |ev, headerString|
				ev.reset;
				headerString.split(Char.nl).do { |line|
					ev.run(line)
				};
			};

		);
	};

	~getMarkersFromSoundFile = { |sf, offset|
		var parser = ~markerParser.value;
		parser.parse(sf.readHeaderAsString);
		parser.getMarkers(offset) !? (~markers.putAll(_));
	};


	~getMarkerTime = { |marker, fallback=true|
		var time;
		time = ~markers[marker];
		if (time.notNil) {
			time / (~settings[\sampleRate] ? 1);
		} {
			if (fallback) {
				case
				{ marker == \start } {
					time = 0;
				}
				{ marker == \end } {
					time = ~getDuration.value;
				}
			}

		}
	};

}, \initData);

Cell.addTemplate(\settings, {

	// Merge in place
	~dictMerge = { |template, obj|
		var keys = (template.keys ++ obj.keys).asArray;
		keys.postln;
		keys.do { |k|
			var v = obj[k];
			if (v.notNil) {
				if (template[k].isNil) {
					template[k] = v;
				} {
					if (template[k].isKindOf(Dictionary) and: { v.isKindOf(Dictionary) } ) {
						~dictMerge.(template[k], v)
					} {
						// Overwrite single values
						template[k] = v;
					}
				};
			}
		};
		template;

	};

	~build = {
		//This is later referred to as ~settings
		~addInstanceData.(\settings, (
			server: { Server.default },
			//Number of out channels
			numChannels: 2,
			// --- DURATIONS ---
			// Total cell duration
			duration: inf,
			// Duration of tail
			// Time until silent after all players have stopped playing.
			// Currently unused for synths (using register + onFree instead)
			// In case of patterns, wait for tailDuration after pattern has stopped.
			// This means you have to add pattern note release time to tailDuration
			tailDuration: 3,
			// --- SYNC ---
			// By default, TempoClock.default is used.
			// Tempo is set on quantized play start.
			// quant.timingOffset can be used to start playback earlier,
			// for example if a sample starts on an upbeat.
			tempo: 60,
			// Quant == grid.
			// Set timingOffset here, if needed
			quant: 0,
			// --- FADES ---
			// Fades are post-fx, and overrides tail settings.
			// This means it should be safe to free everything when a fadeOut has completed.
			// Fade in duration.
			fadeIn: 0,
			// Curve of fadeIn envelope - only float?
			fadeInCurve: 8,
			// Fade out duration. This overrides tailDuration.
			fadeOut: 0,
			// Curve
			fadeOutCurve: -8,
			// If true, release main synths in .templatePostStop
			releaseAfterStop: true,
			// Default arguments for new synths
			defaultSynthArgs:  IdentityDictionary[
				\out -> {~bus.main}
			]
		));
	};

	~numChannelsFormat = { |string|
		string.format(~settings[\numChannels].value)
	};

	~getDuration = {
		~settings[\duration];
	};

	~getQuant = {
		~settings[\quant].asQuant;
	};

	~updateSettings = { |obj|
		~dictMerge.(~settings, obj);
	};
}, \initData);

Cell.addTemplate(\base, {

	~validateArgs = { |args|
		if (args.size.odd) {
			Error("This cell template should have even number of arguments.").throw
		};
		args
	};

	~build = {
		~addInstanceData.(\template, IdentityDictionary());
	};

	~updateTemplate = { |obj|
		~dictMerge.(~template, obj);
	};

}, [\settings, \markers]);

Cell.addTemplate(\server, {
	//FIXME we should not hardcode server here
	//Use settings!

	~templateInit = {
		~server = ~settings[\server].value;
		~server.debug("server");
	};

	~templateLoad = { ~server.bootSync };
	~templatePostLoad = { ~server.sync };

	// --- Server boot / quit ---

	~doOnServerBoot = nil;

	~doOnServerQuit = {
		currentEnvironment.freeAll;
	};

	~init = {
		ServerBoot.add(currentEnvironment, ~server);
		ServerQuit.add(currentEnvironment, ~server);
	};

	~templateFree = {
		ServerBoot.remove(currentEnvironment, ~server);
		ServerQuit.remove(currentEnvironment, ~server);
	};

}, \base);

Cell.addTemplate(\track, {

	~build = {
		~instanceData[\template][\track] = (
			mod: (  ),
			main: (  ),
			fx: (  ),
			//TODO defaultSendTarget/thunk/template
			send: ( out: TrackSend(0, args: (slotType: \trimSend))),
		);
		~instanceData[\settings][\track] = (
			fadeGroup: \send,
			fadeSlot: \out,
			fadeParam: \level,
			numChannels: { ~settings[\numChannels].value },
			//Default send target
			//Uses track syntax, anything that responds to
			//asTrackSlotReceiver
			defaultSendTarget: 0
		)
	};


	~templateInit = {
		//For now, just copy ~settings[\numChannels] to track.
		//TODO make it possible to pass in user settings that's not part of the
		//track settings template
		~template[\track][\settings] = ~settings[\track].collect({ |v|
			v.value;
		});
	};

	~templateLoad = { |cell|
		~track = Track.newFromDict(~template[\track]);
		~track.addDependant(cell);
		~trackAuto = TrackAuto(~track, ~track[~settings[\track][\fadeGroup], ~settings[\track][\fadeSlot]], ~settings[\track][\fadeParam]);
	};

	// All groups end up in the groups envir
	// The envir should not be placed in the parent envir
	// So we create it as a part of ~addGroups
	~templatePreparePlay = {
		var cond = CondVar();
		var cb = { |obj, what|
			if (what == \playing) {
				cond.signalOne;
				obj.removeDependant(cb);
			}
		};
		~track.addDependant(cb).play;
		if (cond.waitFor(1).not) {
			Error("Track could not start").throw;
		};
	};

	~templatePostStop = {
		~track.stop;
	};

	~templateFree = {
		~track.free;
	};

	~update = { |obj, what|
		if (obj == ~track) {
			switch(what,
				\playing, {
					~onTrackPlay.value;
				},
				\stopped, {
					~onTrackStop.value;
				}

			)
		}
	};

	~fadeIn = { |endLevel=1, dur=3, curve|
		//In case we're not ready to play. This will also boot server if needed
		currentEnvironment.load.then {
			~trackAuto.fadeIn(endLevel, dur, curve)
		}
	};

	~fadeOut = { |dur=3, curve, stopCell=false|
		if (stopCell) {
			var stopFunc = { |obj, what|
				if (obj == ~trackAuto and: { what == \finish }) {
					~getCell.value.stop;
				} {
					//Assuming slot object
					if (what == \stopped) {
						//We need to reset to previous value,
						//and it needs to be done after slot has finished playing
						//Then we're ready for replaying cell
						~trackAuto.reset(false);
					}
				};
				obj.removeDependant(stopFunc)
			};
			~trackAuto.slot.addDependant(stopFunc.inEnvir);
			~trackAuto.addDependant(stopFunc.inEnvir);
		};
		~trackAuto.fadeOut(dur, curve)
	}

}, \server);

// Synth related methods: FX, Ctl,
Cell.addTemplate(\synth, {

	~validateArgs = nil -> { |args|
		if (args[0].isSymbol.not and: { args[0].respondsTo(\asTrackGroupItem) }) {
			var synth = args.removeAt(0);
			var key = "%_%".format((synth.tryPerform(\key) ? "synth"), synth.hash.asHexString).asSymbol;
			args = ~dictMerge.value((
				template: (
					track: (
						main: ().put(key, synth)
					)
				)
			), args.asDict);
			args.postln;
		};
		args.asPairs;
	};

	~templatePlay = {
		~track[\main].default = \default;
	}

}, [\track]);



Cell.addTemplate(\buffer, {

	// Buffer template template
	// Multiple files
	/*
	~template.buffer = (
		key0: "/path", // Only expressed as path
		key1: ( //As dict
			path: "/path",
			method: \read,
			startTime: 1.2, // like startFrames, but in seconds
			startFrames: 1000,
			duration: 2.5, // like numFrames
			numFrames: 480000
		)
	);
	*/
	~build = {
		~instanceData[\settings][\buffer] = (
			defaultSynth: { ~numChannelsFormat.("cellBufPlayer_%") },
			defaultBufferMethod: \read,
			cueSize: 65536
		)
	};

	//No dependencies here, please
	~validateArgs = nil -> { |args|
		if (args[0].isString) {
			var path = args.removeAt(0);
			var key = path.basename.splitext[0].asSymbol;
			args = args.asDict;
			args = ~dictMerge.value((
				template: (
					buffer: ().put(key, path)
				)
			), args.asDict);
		};
		args.asPairs;
	};

	~templateInit = {
		var mainTemplate = ~template[\track][\main];
		if (mainTemplate.isEmpty) {
			~template[\buffer] !? { |x|
				~settings[\numChannels] = 0; //let buffers set numChannels
				x.keysValuesChange { |key, obj|
					obj = ~checkFile.(key, obj);
					mainTemplate[key] = TrackSynth(
						~settings[\buffer][\defaultSynth].value,
						//TODO need to dereference this before it becomes a TrackSlotParam
						(bufnum: Thunk({ ~buffers[key] }.inEnvir))
					);
					obj
				}
			};
		};
	};

	~checkFile = { |key, obj|
		var method, channels;

		obj = obj.value;

		if (obj.isKindOf(String)) {
			obj = IdentityDictionary[\path->obj];
		};


		SoundFile.use(obj[\path], { |sf|
			obj[\duration] !? { |dur|
				obj[\numFrames] = (dur.value(sf) * sf.sampleRate).floor;
			};
			obj[\startTime] !? { |start|
				obj[\startFrame] = (start.value(sf) * sf.sampleRate).floor;
			};
			obj[\numChannels] = sf.numChannels;
			~eachSoundFile.(sf, obj);
		}.inEnvir);

		~settings[\numChannels] = ~settings[\numChannels].max(obj[\numChannels]);

		obj;

	};

	~addBuffer = { |key, obj|

		// Free previous buffer if needed
		~buffers[key].free;

		switch (obj[\method] ?? { ~settings[\buffer][\defaultBufferMethod] },
			\read, {
				~buffers[key] = Buffer.read(~server, obj[\path], obj[\startFrame] ? 0, obj[\numFrames] ? -1);
			},
			\cueSoundFile, {
				~buffers[key] = Buffer.cueSoundFile(
					~server, obj[\path], obj[\startFrame] ? 0, obj[\numChannels],
					obj[\bufferSize] ?? { ~settings[\cueSize] ? 65536 };
				);
			}
		);
		~buffers.postln;
	};

	// Add buses according to template
	~templateLoad = {
		var template = ~template[\buffer];
		if (template.notNil) {
			~buffers ?? { ~buffers = IdentityDictionary(know:true) };
			template.keysValuesDo { |key, obj|
				~addBuffer.(key, obj);
			};
		};
	};

	~templateFree = {
		~buffers.do(_.free);
		~buffers.clear;
		~buffers = nil;
	};

}, [\synth]);

Cell.addTemplate(\disk, {

	~build = {
		~instanceData[\settings][\buffer] = (
			setDurationFromFile: true,
			setMarkersFromFile: true,
			//~settings[\defaultSynthArgs][\duration] = { ~settings[\duration] };
			defaultSynth: {
				~numChannelsFormat.("cellDiskPlayer_%");
			},
			defaultBufferMethod: \cueSoundFile,
		)
	};

	~eachSoundFile = { |sf, obj|
		var ffwd = currentEnvironment[\fastForward] ? 0;

		if (~settings[\buffer][\setDurationFromFile]) {
			if (~settings[\duration] == inf) {
				~settings[\duration] = 0;
			};
			~settings[\duration] = max(sf.duration, ~settings[\duration]);
		};

		if (ffwd.isNegative) {
			ffwd = (~settings[\duration] + ffwd).max(0);
			~fastForward = ffwd;
		};


		if (~settings[\buffer][\setMarkersFromFile]) {
			~getMarkersFromSoundFile.(sf, obj[\startFrame]);
		};

		obj[\startFrame] = (obj[\startFrame] ? 0) + (ffwd * sf.sampleRate);

		//FIXME: Check for multiple files/rates
		~settings[\sampleRate] = sf.sampleRate;

	};

}, [\buffer]);


Cell.addTemplate(\group, {

	~build = {
		~instanceData[\cells] = IdentityDictionary(know: true);
	};

	~templateInit = {
		~template[\cells] !? { |x| x.keysValuesDo { |key, cell|
			~cells[key] = cell;
			//currentEnvironment.addChildren(key, cell);
		}};
	};

	//Cell methods needs to be forwarded
	#[load, play, stop, pause, resume, templateFree, free].do { |action|
		currentEnvironment[action] = {
			~cells.do(_.perform(action));
		};
	};

	//And all player-specific methods (set, get etc) is forwarded here
	~forward = { |selector, args|
		~cells.collect { |cell|
			cell.performList(selector, args);
		};
	};

	//Needs base for template
}, [\base]);

Cell.addTemplate(\pattern, {

	~build = {
		// We let pattern release itself
		~instanceData[\settings][\releaseAfterStop] = false;
	};

	~validateArgs = nil -> { |args|
		if (args[0].isKindOf(Pattern)) {
			var ptn = args.removeAt(0);
			args = ~dictMerge.value((
				pattern: ptn
			), args.asDict);
		};
		args.asPairs;
	};

	~templateLoad = { |cell|
		var ptn = Pspawner({ |sp|
			var tempo = cell.clock.tempo;
			var dur = ~settings[\duration] * tempo;
			~spawner = sp;
			sp.seq(Pfindur(dur,
				Penvir(cell,
					Pchain(~pattern,
						Pbind(
							\nilOnStop, Pif(Pfunc { cell.checkState(\stopping, \stopped) }, nil, 1),
							\out, Pfunc({ ~track.asBus }),
							\group, Pfunc({ ~track.asGroup }),
							\progress, Plazy({ Ptime() / ~settings[\duration]})
						)
					), independent: false)
			));

			fork { cell.stop };
		});

		~player = ptn.asEventStreamPlayer;
	};

	~onTrackPlay = {
		if (~player.isPlaying.not) {
			var rest;
			var clock = currentEnvironment.clock;
			~fastForward !? { |ffwd|
				if (ffwd.isNegative) {
					if (~settings[\duration] != inf) {
						ffwd = ~settings[\duration] + ffwd;
					} {
						ffwd = 0;
					};
					~fastForward = ffwd;
				};


				//Adjust from seconds to beats
				/*
				ffwd = ffwd * clock.tempo;

				rest = ~player.originalStream.fastForward(ffwd);
				(rest * clock.tempo / thisThread.clock.tempo).wait;
				*/
			};
			~player.play(clock);
		}
	};

	~templateStop = { |cell|
		try {
			while { ~player.notNil and: { ~player.clock.queue.size >= 2 } } {
				0.1.wait;
			};
		} {
			Error("Error in player % templatePostStop".format(currentEnvironment.name)).throw;
		};

		//Tail duration should equal max release time for synth
		//TODO keep track of synth releases in some clever way
		(~settings.tailDuration * cell.clock.tempo).wait;
	};



}, [\synth]);

Cell.addTemplate(\bufferPattern, {
	~templateInit = {
		~template[\main] = nil;
	};
}, [\pattern, \buffer]);
