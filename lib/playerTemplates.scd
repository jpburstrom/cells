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
		var key, val, out, path;
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
				~prNodeMapSend.(out, path);
			};
		} {
			nil
		};
		out
	};


	~prNodeMapSend = { |map, path|
		var type = path[0];
		var key = path[1];

		//Get playing node from map path
		if (type == \group) {
			map.sendToNode(~groups[key]);
		} {
			~synths[type] !? { |typeDict|
				map.sendToNode(typeDict[key]);
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
		// In case of synths, wait for tailDuration after all synths have stopped.
		// In case of patterns, wait for tailDuration after pattern has stopped.
		// This means you have to add pattern note release time to tailDuration
		// This is useful for delays or reverbs put in the fx group
		// TODO:
		tailDuration: 0,

		// --- SYNC ---
		// By default, TempoClock.default is used.
		// Tempo is set on quantized play start.
		// quant.timingOffset can be used to start playback earlier,
		// for example if a sample starts on an upbeat.
		tempo: 1,
		// Set timingOffset here, if needed
		quant: nil,


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

	~load = { ~server.bootSync };
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

	~build = {
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
			~nodeMap[\group][key].sendToNode(node);
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
	~build = {
		~updateTemplate.((
			bus: (
				//Type, channels, index (for global buses)
				main: [\audio, { ~settings[\numChannels] }],
				out: {
					try { currentEnvironment.mother[\bus][\main] } {
						[\audio, 2, 0]
					};
				}
			)
		));
	};

	//Add a single bus, identified by key
	~addBus = { |key, rate, numChannels, index, grp|
		grp = grp ? \_default;
		~bus[grp][key].free; // Also if nil
		if (rate.isKindOf(Bus)) {
			~bus[grp][key] = rate;
		} {
			if (index.notNil) {
				~bus[grp][key] = Bus(rate, index, numChannels.value, ~server);
			} {
				~bus[grp][key] = Bus.alloc(rate, ~server, numChannels.value ? 2)
			};
		};
		~bus[grp][key];
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

		~template[\bus] !? (_.keysValuesDo { |key, args|
			args = args.value.asArray;
			~addBus.(key, *args);
		});

	};

	~freeAll = {
		~bus.do { |ev|
			ev.do { |bus|
				bus.free;
			}
		};
		~bus.clear;
		~bus = nil;
	};

}, \server);


//XXX FIXME test this, temporary cell thing
Cell.addPlayer(\cells, {

	~init = {
		~cells ?? { ~cells = IdentityDictionary(know:true) };
		~template[\cells].keysValuesDo { |key, args|
			// FIXME should these be cells from the start?
			~cells[key] = Cell(*args);
			currentEnvironment.addChildren(key);
		};
	};

	~play = {
		~cells.do(_.play);
	};

	~stop = {
		~cells.do(_.stop);
	};

	~freeAll = {
		~cells.do(_.free);
	};

}, \base);


Cell.addPlayer(\ctl, {
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
		args[\out] = bus.index;
		~prPlaySynth.(\ctl, key, synth, args);
	};
}, [\bus, \group]);

// Synth related methods: FX, Ctl,
Cell.addPlayer(\synth, {

	~build = {
		~updateTemplate.((
			main: IdentityDictionary(),
			level: IdentityDictionary[
				\main -> { ["cellMixer_%".format(~settings[\numChannels]).asSymbol,
					(fadetime: {~settings[\fadeIn]}, out: {~bus.out}, in: {~bus.main})
				] };
			];
		))
	};

	~addSynthsFromTemplate = {
		var key, synth, args;
		var clock = ~settings[\clock] ? TempoClock.default;
		~synths ?? { ~synths = IdentityDictionary(know:true) };
		clock.schedAbs(~settings[\quant].asQuant.nextTimeOnGrid(clock), {
			~template[\group] !? (_.do { |groupKey|
				~prSynthTemplateLoop.(groupKey, ~prPlaySynth);
			});
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
		~template[group] !? (_.keysValuesDo({ |key, args|
			var synth;
			// Unpack functions from template
			if (args.isFunction) {
				args = args.value;
			};
			synth = args[0];
			args = args[1..];
			if (args.size == 1) {
				args = args[0];
			};
			callback.(group, key, synth, args);
		}));
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
					map.sendToNode(node, ~server.latency);
				}
			}
		};
	};

	~afterInit = ~addSynthNodeMap;
	~beforePlay = ~addSynthsFromTemplate;
	~afterPlay = ~syncSynthNodeMap;

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
		~set.(\level, \main, \fadetime, time ?? { ~settings[\fadeIn] } );
		~set.(\level, \main, \amp, ~get.(\level, \main, \amp) ? 1);
		~set.(\level, \main, \freeWhenDone, 0);
		currentEnvironment.play;
	};

	~fadeOut = { |time, freeWhenDone=true|
		~set.(\level, \main, \fadetime, time ?? { ~settings[\fadeOut] });
		//Access this directly, so nodeMap is not affected
		~synths[\level][\main].set(\amp, 0, \freeWhenDone, freeWhenDone.asInteger);
		currentEnvironment
	};

}, [\bus, \group, \ctl]);




Cell.addPlayer(\buffer, {

	/*
	// Buffer template template
	// Multiple files
	~template.files = (
	key0: "/path",
	key1: (
	path: "/path",
	method: \read,
	startTime: 1.2, // like startFrames, but in seconds
	startFrames: 1000,
	duration: 2.5, // like
	numFrames: 480000,
	numFrames: 480000,
	)
	);
	*/

	~build = {
		~settings[\defaultBufferMethod] = \read;
		~settings[\cueSize] = 65536;
		~settings[\numChannels] = 2;
	};

	~addBuffer = { |key, obj|
		var method, channels;

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
		});

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
				~addBuffer.(key, obj);

			};
		};

	};

	~beforeInit = {
		if (~template[\main].notNil and: { ~template[\main].isEmpty }) {
			~template[\buffer].keys.do { |key|
				~template[\main][key] = [~settings[\defaultSynth],
					\bufnum, {~buffers[key]}];
			};
		};
	};

	~freeAll = {
		~buffers.do(_.free);
		~buffers.clear;
		~buffers = nil;
	};

}, \synth);