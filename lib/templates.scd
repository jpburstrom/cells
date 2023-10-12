Cell.addTemplate(\initData, {
	~templateDescription = "A partial template initializing instance data. Probably not very useful on its own.";

	~templateBuild = {
		~templateInstanceData = IdentityDictionary().know_(true); //Instance-level data
	};

	~templateInit = { |cell|
	};

});

Cell.addTemplate(\markers, {
	var markerParser;

	~templateDescription = "A partial template to read markers from audio files.";

	~templateBuild = {
		//This is created in ~cell, but we refer to it as ~markers since
		//functions are running in instance
		~templateInstanceData.put(\markers, IdentityDictionary());
	};

	markerParser = {
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
		var parser = markerParser.value;
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
	~templateDescription = "A partial template to add default settings";

	// Merge in place
	~templateDictMerge = { |template, obj|
		var keys = (template.keys ++ obj.keys).asArray;
		keys.do { |k|
			var v = obj[k];
			if (v.notNil) {
				if (template[k].isNil) {
					template[k] = v;
				} {
					if (template[k].isKindOf(Dictionary) and: { v.isKindOf(Dictionary) } ) {
						~templateDictMerge.(template[k], v)
					} {
						// Overwrite single values
						template[k] = v;
					}
				};
			}
		};
		template;

	};

	~templateBuild = {
		//This is later referred to as ~settings
		~templateInstanceData[\settings] = (
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
			//Here proto is used backwards -- as temporary storage for default values
		).proto_(());
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

	//Support for changing settings temporarily during a single playback
	~setTempSettings = { |...pairs|
		pairs.keysValuesDo { |k, v|
			~settings.proto[k] = Ref(~settings[k]);
			~settings[k] = v;
		};
		currentEnvironment
	};

	~templatePostStop = {
		~settings.proto.keysValuesDo { |k, v|
			~settings[k] = v.value;
		};
		~settings.proto.clear;
	};

}, \initData);

Cell.addTemplate(\base, {
	~templateDescription = "A base template for other cells, or a bare template for custom behaviour.";

	~templateValidateArgs = { |args|
		if (args.size.odd) {
			Error("This cell template should have even number of arguments.").throw
		};
	};

	~streamFastForward = { |stream|
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
			ffwd = ffwd * clock.tempo;
			rest = stream.fastForward(ffwd);
			rest * thisThread.clock.tempo / clock.tempo;
		} ?? 0;
	};

	~templateBuild = {
		~templateInstanceData.put(\snapshot, IdentityDictionary());
	};

	~templatePlay = {
		if (~settings[\duration].notNil and: { ~settings[\duration] < inf }) {
			~durationCond = CondVar();
			{
				var isTimeout = false == ~durationCond.waitFor(~settings[\duration], { currentEnvironment.state == \stopping });
				if (isTimeout) {
					currentEnvironment.stop;
				};
			}.inEnvir.fork;
		}
	};

	~templateStop = {
		~durationCond !? (_.signalAll);
	};

	~elapsedBeats = {
		currentEnvironment.clock !? { |clock| clock.beats };
	};

	~elapsedSeconds = {
		currentEnvironment.clock !? { |clock| clock.beats / clock.tempo };
	};

	~progress = {
		~settings[\duration] !? { |dur| currentEnvironment.clock !? { |clock| (clock.beats / clock.tempo) / dur } };
	};

}, [\settings, \markers]);

Cell.addTemplate(\server, {
	~templateDescription = "A base template for all cell types dealing with the server.";
	//FIXME we should not hardcode server here
	//Use settings!


	// --- Server boot / quit ---

	~doOnServerBoot = nil;



	~doOnServerQuit = {
		currentEnvironment.freeAll;
	};

	~templateBuild = {
		~templateInstanceData[\settings].putAll((
			server: { Server.default },
			//Number of out channels
			numChannels: 2,
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
		))
	};

	~templateInit = { |cell|
		~server = ~settings[\server].value;
		ServerBoot.add(cell, ~server);
		ServerQuit.add(cell, ~server);
	};

	~templateLoad = { ~server.bootSync };
	~templatePostLoad = { ~server.sync };

	//This is run inside cell environment, maybe it should be in proto w/ cell arg?
	~templateFree = {
		ServerBoot.remove(currentEnvironment, ~server);
		ServerQuit.remove(currentEnvironment, ~server);
	};

}, \base);

Cell.addTemplate(\track, {
	~templateDescription = "A template creating a track from a track template (sic). ";

	~templateBuild = {
		~templateInstanceData[\trackTemplate] = (
			mod: (  ),
			main: (  ),
			fx: (  ),
			//TODO defaultSendTarget/thunk/template
			send: ( out: TrackSend(0, args: (slotType: \trimSend)) ),
		);
		~templateInstanceData[\settings][\track] = (
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


	~templateInit = { |cell|
		//For now, just copy ~settings[\numChannels] to track.
		//TODO make it possible to pass in user settings that's not part of the
		//track settings template
		~trackTemplate[\settings] = ~settings[\track].collect({ |v|
			v.value;
		});
	};

	~templateLoad = { |cell|
		~track = Track.newFromDict(~trackTemplate.deepCopy);
		~track.addDependant(cell);
		~trackFader = TrackAuto(~track, ~track[~settings[\track][\fadeGroup], ~settings[\track][\fadeSlot]], ~settings[\track][\fadeParam]);
		if (~settings[\fadeIn] != 0) {
			var endLevel = ~settings[\fadeInEndLevel] ? 1; //Fixme get this from param. trackFader feature?
			~trackFader.fadeIn(endLevel, ~settings[\fadeIn], ~settings[\fadeInCurve]);
		}
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

	~templateStop = {
		var cond = CondVar();
		var fadeDur = ~settings[\fadeOut];
		if (fadeDur > 0) {
			{
				var func = {
					cond.signalAll;
				};
				~trackFader.addDependant(func);
				~fadeOut.(fadeDur, ~settings[\fadeOutCurve], false);
			}.inEnvir.fork;
			cond.waitFor(fadeDur + 1);
		};
	};



	~templatePostStop = {
		//Will stop and free track
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
		currentEnvironment.stop(true).then({
			~setTempSettings.(
				\fadeInEndLevel, endLevel,
				\fadeIn, dur,
				\fadeInCurve, curve
			);
			currentEnvironment.play;
		})
	};

	~fadeOut = { |dur=3, curve, stopCell=false|
		if (stopCell || currentEnvironment.checkState(\stopping)) {
			var stopFunc = { |obj, what|
				if (obj == ~trackFader and: { what == \finish }) {
					//fadeOut can be called either by user or as part of a stop routine
					//If called by user, we're not yet stopping so we need to do that here
					//Otherwise just continue the stop routine
					if (currentEnvironment.checkState(\stopping).not) {
						currentEnvironment.stop;
					};
				} {
					//Assuming slot object
					if (what == \stopped) {
						//We need to reset to previous value,
						//and it needs to be done after slot has finished playing
						//Then we're ready for replaying cell
						~trackFader.reset(false);
					}
				};
				obj.removeDependant(stopFunc)
			}.inEnvir;
			~trackFader.slot.addDependant(stopFunc);
			~trackFader.addDependant(stopFunc);
			//Won't need tail since we're fading
			~setTempSettings.(\tailDuration, 0);
		};
		~trackFader.fadeOut(dur, curve);
	};

	~getSnapshot = {
		~snapshot[\track] = ~track.getSnapshot;
		~snapshot;
	};

	~setSnapshot = { |snapshot|
		~track.setSnapshot(snapshot[\track]);
	}

}, \server);

// Synth related methods: FX, Ctl,
Cell.addTemplate(\synth, {
	~templateDescription = "A player extending the track player to play synths quantized and in sync with other players.";

	~templateBuild = {
		~templateInstanceData[\synthTemplate] = (
			main: (  ),
			fx: (  ),
		);
	};

	~templateValidateArgs = nil -> { |args|
		if (args[0].isKindOf(Symbol).not and: { args[0].respondsTo(\asTrackGroupItem) }) {
			var synth = args.removeAt(0);
			var key = "%_%".format((synth.tryPerform(\key) ? "synth"), synth.hash.asHexString).asSymbol;
			if (args.includes(\synthTemplate)) {
				args.pairsDo { |k, v|
					if (k == \synthTemplate) {
						args[k] = ~templateDictMerge.value((
							main: ().put(key, synth)
						), v);
					}
				}
			} {
				args.addAll([\synthTemplate, (
					main: ().put(key, synth)
				)]);
			};
		}
	};

	//~synthTemplate has same structure as ~trackTemplate
	//The main difference is when it's being played
	//~trackTemplate is played on ~templateLoad
	//~synthTemplate on ~templatePlay
	~templatePlay = {
		~synthTemplate.keysValuesDo { |groupKey, dict|
			dict.keysValuesDo { |key, slot|
				~track[groupKey][key] = slot;
			};
		};
	}

}, [\track]);



Cell.addTemplate(\buffer, {
	~templateDescription = "A buffer player, cueing file(s) from a buffer template.\n
	//Template format
	(
		key0: \"/path\", // Only expressed as path
		key1: ( //As dict
			path: \"/path\",
			method: 'read',
			startTime: 1.2, // like startFrames, but in seconds
			startFrames: 1000,
			duration: 2.5, // like numFrames
			numFrames: 480000
		)
	);
";
	~templateBuild = {
		~templateInstanceData[\settings][\buffer] = (
			defaultSynthDef: { ~numChannelsFormat.("cellBufPlayer_%") },
			defaultBufferMethod: \read,
			cueSize: 65536
		)
	};

	//No dependencies here, please
	~templateValidateArgs = nil -> { |args|
		if (args[0].isString) {
			var path = args.removeAt(0);
			var key = path.basename.splitext[0].asSymbol;
			if (args.includes(\bufferTemplate)) {
				args.pairsDo { |k, v|
					if (k == \bufferTemplate) {
						args[k] = ~templateDictMerge.value(().put(key, path), v);
					}
				}
			} {
				args.addAll([\bufferTemplate, ().put(key, path)]);
			};
		};
	};

	~templateInit = { |cell|
		var mainTemplate = ~synthTemplate[\main];
		if (mainTemplate.isEmpty) {
			~bufferTemplate !? { |x|
				~settings[\numChannels] = 0; //let buffers set numChannels
				x.keysValuesDo { |key, obj|
					obj = cell.getSoundFileData(key, obj);
					obj[\instrument] = obj[\instrument] ?? ~settings[\buffer][\defaultSynthDef];
					obj[\bufnum] = { ~buffers[key] }.inEnvir;
					mainTemplate[key] = obj; //
				}
			};
		};
	};

	~getSoundFileData = { |key, obj|
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
	};

	// Add buses according to template
	~templateLoad = {
		var template = ~bufferTemplate;
		if (template.notNil) {
			~buffers ?? { ~buffers = IdentityDictionary(know:true) };
			template.keysValuesDo { |key, obj|
				obj = ~getSoundFileData.(key, obj);
				~addBuffer.(key, obj);
			};
		};
	};

	~templatePostStop = {
		~buffers.do(_.free);
		~buffers.clear;
		~buffers = nil;
	};

}, [\synth]);

Cell.addTemplate(\disk, {
	~templateDescription = "A disk player, cueing file(s) from a buffer template.";

	~templateBuild = {
		~templateDictMerge.(~templateInstanceData[\settings], (
			buffer: (
				setDurationFromFile: true,
				setMarkersFromFile: true,
				//~settings[\defaultSynthDefArgs][\duration] = { ~settings[\duration] };
				defaultSynthDef: {
					~numChannelsFormat.("cellDiskPlayer_%");
				},
				defaultBufferMethod: \cueSoundFile,
			)
		))
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
	~templateDescription = "A cell holding a group of cells, forwarding methods to all cells.";

	~templateValidateArgs = nil -> { |args|
		if (args[0].isKindOf(Collection)) {
			var coll = args.removeAt(0);
			args.addAll([\cells, coll]);
		};

		if (args.asDict.keys.includes(\cells).not) {
			Error("Cell collection is missing in group cell").throw
		}
	};

	//Cell methods needs to be forwarded
	#[load, play, stop, pause, resume, free].do { |action|
		currentEnvironment[action] = {
			~cells.do(_.perform(action));
		};
	};

	//And all player-specific methods (set, get etc) is forwarded here
	~forward = { |selector ...args|
		~cells.collect { |cell|
			//Add default arguments to functions
			[selector, args].postln;
			if (cell[selector].isFunction) {
				var defaults = cell[selector].def.keyValuePairsFromArgs.clump(2).flop[1];
				args = defaults.collect { |v, i| args[i] ? v };
			};
			cell.performList(selector, args);
		};
	};

	//Needs base for template
}, [\base]);

Cell.addTemplate(\basicPattern, {

	~templateDescription = "A basic pattern player useful for midi or data patterns, or for custom routing.";

	~templateBuild = {
		// We let pattern release itself
		~templateInstanceData[\settings][\releaseAfterStop] = false;
	};

	~templateValidateArgs = nil -> { |args|
		if (args[0].isKindOf(Pattern)) {
			var ptn = args.removeAt(0);
			args.addAll([\pattern, ptn])
		};
	};

	~templateLoad = { |cell|
		var ptn = ~pattern;
		~player = ~wrapperPattern.(cell, ptn).asEventStreamPlayer;
	};

	~wrapperPattern = { |cell, ptn|
		~settings[\randSeed] !? { |seed|
			ptn = Pseed(seed, ptn);
		};

		Pspawner({ |sp|
			var tempo = cell.clock.tempo;
			var dur = ~settings[\duration] * tempo;
			~spawner = sp;
			sp.seq(Pfindur(dur,
				Penvir(cell,
					Pchain(ptn,
						~chainPattern.value(cell);
					), independent: false)
			));

			if (cell.checkState(\stopping).not) { fork { cell.stop } };
		});
	};

	~chainPattern = { |cell|
		Pbind(
			\nilOnStop, Pif(Pfunc({
				cell.checkState(\stopping, \stopped) && (~trackFader.isPlaying.not)
			}), nil, 1),
			\progress, Pfunc({ ~progress.value ? 0 }),
			\elapsedSeconds, Pfunc({ ~elapsedSeconds.value ? 0 }),
			//Beats can use Ptime()
		)
	};

	~templatePlay = {
		if (~player.isPlaying.not) {
			~streamFastForward.(~player.originalStream).wait;
			~player.play(currentEnvironment.clock);
		}
	};

	~templateStop = { |cell|
		if (cell.clock.isRunning) {
			try {
				while { cell.clock.queue.size >= 2 } {
					0.1.wait;
				};
			} {
				Error("Error in player % templateStop".format(currentEnvironment.name)).throw;
			};

			//Tail duration should equal max release time for synth
			//TODO keep track of synth releases in some clever way
			(~settings[\tailDuration] * thisThread.clock.tempo).wait;
		}
	};



}, [\base]);

Cell.addTemplate(\pattern, {
	~templateDescription = "A pattern player creating and playing within a local track instance.";

	~chainPattern = nil -> { |cell|
		Pbind(
			\nilOnStop, Pif(Pfunc({
				cell.checkState(\stopping, \stopped) && (~trackFader.isPlaying.not)
			}), nil, 1),
			\out, Pfunc({ ~track.asBus }),
			\group, Pfunc({ ~track.asGroup }),
			\progress, Pfunc({ ~progress.value ? 0 }),
			\elapsedSeconds, Pfunc({ ~elapsedSeconds.value ? 0 }),
			//Beats can use Ptime()
		)
	};

}, [\basicPattern, \synth]);


Cell.addTemplate(\trigPattern, {
	~templateDescription = "A pattern player where events are triggered on demand.";

	~templateBuild = {
		~templateInstanceData[\settings][\trigOnPlay] = false;
	};

	~wrapperPattern = nil -> { |cell, ptn|
		~settings[\randSeed] !? { |seed|
			ptn = Pseed(seed, ptn);
		};
		Penvir(cell,
			Pchain(ptn,
				~chainPattern.value(cell);
			), independent: false)
	};


	~templateLoad = \synth -> { |cell|
		var ptn = ~pattern;
		~stream = ~wrapperPattern.(cell, ptn).asStream;

	};

	~templatePlay = \synth -> {
		~triggerDepFunc = { |...args|
			//Triggers are a list of [obj, what, args] that are matched with incoming messages
			//It can also be list -> func
			//Where func is filtering the incoming message, returning a dictionary or nil
			//to be used as inval to the triggered event
			~triggers.do { |trigger|
				var t_args, func;
				if (trigger.respondsTo(\key)) {
					t_args = trigger.key;
					func = trigger.value;
				} {
					t_args = trigger;
					func = { |...args|
						if (args[t_args.size].isKindOf(IdentityDictionary)) {
							args[t_args.size]
						}
					}
				};
				if (t_args == args.keep(t_args.size)) {
					var inval = func.valueArray(args) ? ();
					{ ~trig.value(inval) }.fork(currentEnvironment.clock, ~settings[\trigQuant]);
				}
			}
		}.inEnvir;
		~triggers.do { |args|
			(args.tryPerform(\key) ?? args)[0].addDependant(~triggerDepFunc);
		};
		if (~settings[\trigOnPlay]) {
			~trig.value;
		}
	};

	~templateStop = { |cell|
		~triggers.do { |args|
			(args.tryPerform(\key) ?? args)[0].removeDependant(~triggerDepFunc);
		}
	};

	~trig = { |inval|
		inval = inval ?? { () };
		{ ~stream.next(inval).play }.fork(currentEnvironment.clock);
	}

}, [\pattern]);

Cell.addTemplate(\bufferPattern, {
	~templateDescription = "A pattern player with support for loading buffers from a buffer template.";

	~templateInit = {
		~template[\main] = nil;
	};
}, [\pattern, \buffer]);

Cell.addTemplate(\task, {
	~templateDescription = "A simple task player useful for oneshots or looping tasks.";

	~templateValidateArgs = nil -> { |args|
		var task;
		if (args[0].isFunction) {
			task = Task(args.removeAt(0).inEnvir)
		};
		args.addAll([\task, task])
	};
	~templateLoad = {
		~task = ~template[\task];
	};
	~templatePlay = {
		var userStopped = false;
		var update = { |obj, what|
			if (what == \userStopped) {
				userStopped = true;
			};
			if (what == \stopped) {
				if (userStopped.not) {
					currentEnvironment.stop;
				}
			}
		}.inEnvir;
		~task.addDependant(update);
		~task.play(currentEnvironment.clock, true);
	};

	~templateStop = {
		~task.stop.reset;
	}
}, [\base]);
