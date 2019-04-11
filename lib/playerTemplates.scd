Cell.addPlayer(\nodeMap, {

	~nodeMap = MultiLevelIdentityDictionary();

	~addNodeMap = { |...path|
		var map = ~nodeMap.atPath(path);
		if (map.isNil) {
			map = NodeMap();
			~nodeMap.putAtPath(path, map);
		};
		map
	};

	// Get values from running synths
	~get = { |first ...rest|
		var out, path;
		if (first.isKindOf(String)) {
			first = first.split($.).collect(_.asSymbol);
		} {
			first = first.asArray;
		};
		path = first ++ rest;
		out = ~nodeMap.at(*path);
	};

	~set = { |first ...rest|
		var key, val, out, path, node;
		if (first.isKindOf(String)) {
			first = first.split($.).collect(_.asSymbol);
		} {
			first = first.asArray;
		};
		path = first ++ rest;
		val = path.pop;
		key = path.pop;
		out = ~nodeMap.at(*path);
		if (out.isKindOf(NodeMap)) {
			out.set(key, val);
			if (currentEnvironment.isPlaying) {
				var node = ~prGetNodeFromPath.(*path);
				//FIXME: Weird check. Groups are created immediately and currently
				//not registered, so they will never be playing.
				//Like this, group messages will never be sent with latency,
				//which means they will not work immediately after play
				var latency = if(node.isKindOf(Synth) && node.isPlaying.not, ~server.latency);
				out.sendToNode(node, latency);
			};
		};
		out
	};

	~prGetNodeFromPath = { |type, key|
		//Get playing node from map path
		if (type == \group) {
			~groups[key]
		} {
			~synths[type] !? { |typeDict|
				typeDict[key];
			}
		}
	};

});

Cell.addPlayer(\settings, {

	~settings = (
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

		// If true, release main synths in .afterStop
		releaseAfterStop: true,


		// Default arguments for new synths
		defaultSynthArgs:  IdentityDictionary[
			\out -> {~bus.main}
		]
	);
});

Cell.addPlayer(\base, {

	~template = IdentityDictionary();
	~updateTemplate = { |obj|
		// Merge in place
		var dictMerge = { |template, obj|
			obj.keysValuesDo { |k, v|
				if (template[k].isNil) {
					template[k] = v;
				} {
					if (template[k].isKindOf(Dictionary) and: { v.isKindOf(Dictionary) } ) {
						dictMerge.(template[k], v)
					} {
						// Overwrite single values
						template[k] = v;
					}
				};
			};

		};
		dictMerge.(~template, obj);
	};

}, [\settings]);

Cell.addPlayer(\server, {
	//FIXME we should not hardcode server here
	//Use function ?
	~server = Server.default;

	//Default group for synths etc
	~defaultGroup = nil;

	// Group to put everything else
	// If nil, default group (1)
	// Set this before load
	~parentGroup = {
		// If cell has mother, set parentGroup to its main group
		// Override for other behaviour
		currentEnvironment.mother !? (_.defaultGroup);
	};

	~beforeLoad = { ~server.bootSync };
	~afterLoad = { ~server.sync };

	// --- Server boot / quit ---

	~doOnServerBoot = nil;

	~doOnServerQuit = {
		currentEnvironment.freeAll;
	};

	~init = {
		ServerBoot.add(currentEnvironment, ~server);
		ServerQuit.add(currentEnvironment, ~server);
	};

	~freeAll = {
		ServerBoot.remove(currentEnvironment, ~server);
		ServerQuit.remove(currentEnvironment, ~server);
	};

}, [\base, \nodeMap]);

Cell.addPlayer(\group, {
	// Default group order
	// TODO: nested groups, if needed

	~beforeInit = {
		~updateTemplate.((
			group: #[ctl, main, fx, level, send],
			defaultGroup: \main
		));
	};

	~addGroup = { |key, parent|
		var group, msg;
		~groups[key] !? (_.free);
		//If parent is set, use that
		// Otherwise, use parentGroup. If nil,
		// it defaults to Group(1) (nil.asTarget)
		parent = parent ?? ~parentGroup; // calls .value on ~parentGroup
		group = Group.basicNew(~server);
		msg = group.addToTailMsg(parent);
		~groups[key] = group;
		//No need to have latency here, do it as fast as possible
		~server.sendBundle(nil, msg);
		group
	};

	// All groups end up in the groups envir
	// The envir should not be placed in the parent envir
	// So we create it as a part of ~addGroups
	~beforePlay = {
		~groups ?? { ~groups = IdentityDictionary(know:true) };
		~template[\group].do { |key|
			~addGroup.value(key);
		};
		~defaultGroup = ~groups[~template[\defaultGroup]];
	};

	~afterInit = {
		// add node map
		~template[\group].do { |key|
			~addNodeMap.(\group, key);
		};
	};

	~afterPlay = {
		//Sync node map
		~groups.keysValuesDo { |key, node|
			var map = ~nodeMap[\group][key];
			if (map.notEmpty) {
				map.sendToNode(node, ~server.latency);
			}
		};
	};

	~freeAll = {
		~groups.do(_.free);
		~groups.clear;
		~groups = nil;
	}

}, \server);


Cell.addPlayer(\bus, {

	// Buses, following the group scheme above
	// Buses are private by default, but
	// you can provide an index for global buses
	// TODO: a way to inject buses from outside
	~beforeInit = {
		~updateTemplate.((
			bus: (
				//Type, channels, index (for global buses)
				main: [\audio, { ~settings[\numChannels] }],
				out: {
					try { currentEnvironment.mother[\bus].main } {
						[\audio, 2, 0]
					};
				}
			)
		));
	};

	//Add a single bus, identified by key
	~addBus = { |key, rate, numChannels, index, grp|
		var bus;
		grp = grp ? \_default;
		~bus[grp][key].free; // Also if nil
		if (rate.isKindOf(CellBus)) {
			bus = rate;
		} {
			if (index.notNil) {
				bus = CellBus(rate, index, numChannels.value, ~server);
			} {
				bus = CellBus.alloc(rate, ~server, numChannels.value ? 2)
			};
		};
		bus.owner ?? {
			bus.owner_(currentEnvironment);
		};
		~bus[grp][key] = bus;
		bus;

	};

	// Add buses according to template
	~beforeLoad = {
		~bus ?? { ~bus = (
			_default: (),
			_ctl: (),
			// We use a strange feature of events:
			// when calling ~bus.foo, the event is forwarding the
			// message to this function, which tries to find it
			// and otherwise forwards it the _default event
			// so we still can use ~bus.foo for accessing buses
			forward: { |self, key|
				if (self[key].notNil) {
					self[key].value;
				} {
					self[\_default][key]
				}
			}
		)};

		~template[\bus] !? { |x| x.keysValuesDo { |key, args|
			args = args.value.asArray;
			~addBus.(key, *args);
		}};

	};

	~freeAll = {
		~bus.reject(_.isFunction).do { |ev|
			ev.do { |bus|
				bus.releaseBus(currentEnvironment);
			}
		};
		~bus.clear;
		~bus = nil;
	};

}, \server);

// Synth related methods: FX, Ctl,
Cell.addPlayer(\synth, {

	~numChannelsFormat = { |string|
		string.format(~settings[\numChannels]).asSymbol;
	};

	~beforeInit = {
		~settings[\defaultSynth] = \default;
		~updateTemplate.((
			main: IdentityDictionary(),
			level: IdentityDictionary[
				\main -> { [~numChannelsFormat.("cellMixer_%"),
					(
						fadetime: { ~settings[\fadeIn] },
						out: { ~bus.out },
						in: { ~bus.main }
					)
				] };
			];
		))
	};

	~addSynthsFromTemplate = {
		var key, synth, args;
		var clock = ~settings[\clock] ? TempoClock.default;
		~synths ?? { ~synths = IdentityDictionary(know:true) };
		clock.schedAbs(~settings[\quant].asQuant.nextTimeOnGrid(clock), {
			//FIXME: don't change tempo before beat (timingOffset);
			clock.tempo = ~settings[\tempo] / 60;
			~template[\group] !? { |x| x.do { |groupKey|
				if (groupKey == \ctl) {
					~prSynthTemplateLoop.(\ctl, ~prPlayCtl);
				} {
					~prSynthTemplateLoop.(groupKey, ~prPlaySynth);
				}
			}};
			~syncSynthNodeMap.value;
			nil
		}.inEnvir);
	};

	~addSynthNodeMap = {
		~template[\group].do { |groupKey|
			~prSynthTemplateLoop.(groupKey, { |group, key, synth, args|
				var map;
				map = ~addNodeMap.(group, key);
			});
		};

	};

	~prSynthTemplateLoop = { |group, callback|
		~template[group] !? { |x| x.keysValuesDo({ |key, args|
			var synth;
			// Unpack functions from template
			if (args.isFunction) {
				args = args.value;
			};
			args = args.asArray;
			synth = args[0].value;
			args = args[1..];
			if (args.size == 1) {
				args = args[0];
			};
			callback.(group, key, synth, args);
		})};
	};

	// Callback for synth.onFree
	// Removes synth from ~synths set
	~onSynthFree = { |group, key|
		~synths !? {
			~synths[group][key] = nil;

			//Things to do when no synths are playing inside group
			if (~synths[group].isEmpty) {
				switch(group,

					// We're checking if any main or fx synths are still playing
					// If no main synths are left:
					//   If fx are playing, release the fx synths
					//   Otherwise free the cell

					// If no fx synths are left:
					//    If no main synths are playing, free the cell

					// Ctl and volume synths are just abruptly free'd.
					\main, {
						if (~synths[\fx].notNil) {
							if (~synths[\fx].notEmpty) {
								~groups[\fx].release;
							} {
								//If we're last synth playing, free after release
								currentEnvironment.freeAll;
							}
						} {
							currentEnvironment.freeAll;
						}

					},
					\fx, {
						// Free cell when fx and main are not playing anymore
						if (~synths[\main].isNil or: { ~synths[\main].isEmpty }) {
							currentEnvironment.freeAll;
						}
					},
					//If level synth is gone, free everything
					\level, {
						currentEnvironment.freeAll;
					}
				);

			}
		}

	};

	// Add synth
	~addSynth = { |key, synth, args|

		~prPlaySynth.(\main, key, synth, args)
	};

	// Add effect synth
	~addFx = { |key, synth, args|
		~prPlaySynth.(\fx, key, synth, args);
	};


	// Helper method for adding synths
	~prPlaySynth = { |group, key, synth, args|
		var out;
		args = ~settings[\defaultSynthArgs].copy.putAll(args);
		args = args.collect(_.value);
		~nodeMap.at(group, key).putAll(args);
		// Send using default latency, to sync with patterns et al
		s.bind({
			if (synth.isFunction) {
				out = synth.play(~groups[group], args[\out], args: args.asPairs);
			} {
				// Assume we have a symbol
				out = Synth(synth, args.asPairs, ~groups[group]);
			}
		});
		~synths[group] ?? { ~synths[group] = IdentityDictionary() };
		~synths[group][key] = out;
		out.onFree({ |syn|
			~onSynthFree.(group, key);
		}.inEnvir);
		out;
	};

	~syncSynthNodeMap = {
		~synths.keysValuesDo { |type, dict|
			dict.keysValuesDo { |key, node|
				~nodeMap[type][key] !? { |map|
					// Use default latency, to sync with s.bind in ~prPlaySynth
					map.updateArgs;
					map.sendToNode(node, ~server.latency);
				}
			}
		};

	};

	~afterInit = ~addSynthNodeMap;
	~beforePlay = ~addSynthsFromTemplate;

	// Default stop: Call release on synths
	// and let them free the cell when done playing
	~afterStop = {
		if (~settings.releaseAfterStop) {
			~defaultGroup.release;
		}
	};

	~afterFree = {
		~synths.clear;
		~synths = nil;
	};

	~fadeIn = { |time|
		~set.(\level, \main, \freeWhenDone, 0);
		currentEnvironment.load.then {
			if (currentEnvironment.state == \ready) {
				var oldFade;
				if (time.notNil) {
					oldFade = ~settings[\fadeIn];
					~settings[\fadeIn] = time;
				};
				currentEnvironment.play.then {
					oldFade !? { ~settings[\fadeIn] = oldFade };
				};
			}
		};
	};

	~fadeOut = { |time, freeWhenDone=true|
		//~set.(\level, \main, \fadetime, time ?? { ~settings[\fadeOut] });
		//Access this directly, so nodeMap is not affected
		~synths[\level][\main].set(
			\amp, 0,
			\freeWhenDone, freeWhenDone.asInteger,
			\fadetime, time
		);
		currentEnvironment
	};

	// Get bus from ctl key
	~ctlBus = { |key|
		~bus[\_ctl][key];
	};

	// Get a kr player from ctl key
	~ctlKr = { |key|
		var bus = ~bus[\_ctl][key];
		In.kr(bus, bus.numChannels);
	};

	// Get a pattern from ctl key
	// Stolen from Pkr (BenoitLib)
	~ctlPattern = { |key|
		var last = 0, check;
		var busEnvir = ~bus[\_ctl];
		check = { ~server.hasShmInterface }.try;

		check.if ({
			^Pfunc({ busEnvir[key].getSynchronous });
		}, {
			"No shared memory interface detected".warn;
			busEnvir[key].get({|v| last = v;});
			^Pfunc({ busEnvir[key].get({ |v| last = v; }); last });
		});
	};

	// Add control synth (LFO etc)
	~addCtl = { |key, synth, args, numChannels|
		var bus;
		numChannels = numChannels ? 1;
		bus = ~addBus.(key, \control, numChannels, nil, \_ctl);
		args = (args ?? IdentityDictionary()).asDict;
		args[\out] = bus;
		~prPlaySynth.(\ctl, key, synth, args);
	};

	~prPlayCtl = { |grp, key, synth, args|
		var numChannels = nil;
		~addCtl.(key, synth, args, numChannels);
	};

}, [\group, \bus]);



Cell.addPlayer(\buffer, {

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

	~beforeInit = {
		~settings[\defaultSynth] = { ~numChannelsFormat.("cellBufPlayer_%") };
		~settings[\defaultBufferMethod] = \read;
		~settings[\cueSize] = 65536;
		~settings[\numChannels] = 2;
		if (~template[\main].notNil and: { ~template[\main].isEmpty }) {
			~template[\buffer] !? { |x|
				x.keys.do { |key|
					~template[\main][key] = {
						[~settings[\defaultSynth],
							\bufnum, {~buffers[key]}]
					};
				}
			};
		};
	};

	~addBuffer = { |key, obj|
		var method, channels;

		obj = obj.value;

		if (obj.isKindOf(String)) {
			obj = IdentityDictionary[\path->obj];
		};

		SoundFile.use(obj[\path], { |sf|
			obj[\duration] !? { |dur|
				obj[\numFrames] = (dur * sf.sampleRate).floor;
			};
			obj[\startTime] !? { |start|
				obj[\startFrame] = (start * sf.sampleRate).floor;
			};
			channels = sf.numChannels;
			~eachSoundFile.(sf);
		}.inEnvir);

		~settings[\numChannels] = ~settings[\numChannels].max(channels);
		~numChannelsFormat.("cellBufPlayer_%");

		switch (obj[\method] ?? { ~settings[\defaultBufferMethod] },
			\read, {
				~buffers[key] = Buffer.read(~server, obj[\path], obj[\startFrame] ? 0, obj[\numFrames] ? -1);
			},
			\cueSoundFile, {
				~buffers[key] = Buffer.cueSoundFile(
					~server, obj[\path], obj[\startFrame] ? 0, channels,
					obj[\bufferSize] ?? { ~settings[\cueSize] ? 65536 };
				);
			}
		);
	};

	// Add buses according to template
	~beforeLoad = {
		var template = ~template[\buffer];
		if (template.notNil) {
			~buffers ?? { ~buffers = IdentityDictionary(know:true) };
			template.keysValuesDo { |key, obj|
				~settings[\numChannels] = 0;
				~addBuffer.(key, obj);

			};
		};
	};

	~freeAll = {
		~buffers.do(_.free);
		~buffers.clear;
		~buffers = nil;
	};

}, [\synth]);

Cell.addPlayer(\disk, {
	~beforeInit = {
		~settings[\duration] = 0;
		~settings[\setDurationFromFile] = true;
		~settings[\defaultSynth] = {
			~numChannelsFormat.("cellDiskPlayer_%");
		};
		~settings[\defaultBufferMethod] = \cueSoundFile;
	};

	~eachSoundFile = { |sf|
		if (~settings[\setDurationFromFile]) {
			~settings[\duration] = max(sf.duration, ~settings[\duration]);
		}
	};

}, [\buffer]);


Cell.addPlayer(\cells, {

	~beforeInit = {
		~cells ?? { ~cells = IdentityDictionary(know:true) };
		~template[\cells] !? { |x| x.keysValuesDo { |key, cell|
			~cells[key] = cell;
			currentEnvironment.addChildren(key, cell);
		}};
	};

	//Cell methods needs to be forwarded
	#[load, play, stop, pause, resume, freeAll, free].do { |action|
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
}, [\synth]);

Cell.addPlayer(\pattern, {

	~beforeInit = {
		// We let pattern release itself
		~settings[\releaseAfterStop] = false;
	};

	~beforeLoad = {
		~player = EventPatternProxy(Pspawner({ |sp|
			~spawner = sp;
			sp.seq(Pchain(~pattern, Pbind(
				\nilOnStop, Pif(Pfunc { currentEnvironment.checkState(\stopping, \stopped) }, nil, 1),
				\out, Pfunc { ~bus !? (_.main) },
				\group, Pfunc { ~groups !? (_.main) }
			)));

			sp.wait(~settings.tailDuration);

			case
			{ ~synths.isNil } {
				currentEnvironment.freeAll;
			}
			{~synths[\main].notNil and: { ~synths[\main].notEmpty }} {
				~groups[\main].release;
			}
			{ ~synths[\fx].notNil and: { ~synths[\fx].notEmpty } } {
				~groups[\fx].release;
			}
			{ currentEnvironment.freeAll };
		})).quant_(~settings[\quant]);
	};

	~afterPlay = {
		if (~player.isPlaying.not) {
			~player.play;
		};
	};



}, [\synth]);
