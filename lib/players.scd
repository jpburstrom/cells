Environment.make({
	var makeEnv = { |func, mixins|
		var fact = ~mixins;
		if (mixins.isNil) {
			//This also defines order of execution.
			mixins = [\settings, \server, \group, \bus, \ctl];
		};
		Environment.make {
			mixins.do { |key|
				fact[key].value;
			};
			func.value;
		};
	}.inEnvir;

	// An environment of functions
	// defining a number of default settings and methods for higher-level
	// objects.
	~mixins = Environment.make({

		~settings = {




			// Dictionary for param/bus/buffer/group/synth templates
			~template = ();

			// Dictionary of markers
			// label -> tim
			// Time can be a single float
			// or an array of floats
			// (for onsets, phrases etc)
			~markers = nil;

			// We don't set params here, but in proto object

			~params = nil;




			~addCellsFromTemplate = {
				~cells ?? { ~cells = IdentityDictionary(know:true) };
				~template[\cells].keysValuesDo { |key, args|
					~cells[key] = Cell(*args);
					currentEnvironment.addChildren(key);
				};

			};

			~beforeLoad = ~beforeLoad.addFunc(~addCellsFromTemplate);


		};

		// Methods + default settings for groups
		~group = {
			// Default group order
			// TODO: nested groups, if needed
			~template[\group] = #[ctl, main, fx, level, send];
			~template[\defaultGroup] = \main;

			// All groups end up in the groups envir
			// The envir should not be placed in the parent envir
			// So we create it as a part of ~addGroups
			~addGroupsFromTemplate = {
				~groups ?? { ~groups = IdentityDictionary(know:true) };
				~template[\group].do { |key|
					~addGroup.value(key);
				};
				~defaultGroup = ~groups[~template[\defaultGroup]];
			};

			~addGroupNodeMap = {
				~template[\group].do { |key|
					~addNodeMap.(\group, key);
				};
			};

			~syncGroupNodeMap = {
				~groups.keysValuesDo { |key, node|
					~nodeMap[\group][key].sendToNode(node);
				};
			};

			~afterInit = ~afterInit.addFunc(~addGroupNodeMap);
			// Default beforePlay action
			// If this is overridden by main envir,
			// it needs to call addGroups... at some point
			~beforePlay = ~beforePlay.addFunc(~addGroupsFromTemplate);
			~afterPlay = ~afterPlay.addFunc(~syncGroupNodeMap);


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

			~afterFree = ~afterFree.addFunc({
				~groups.do(_.free);
				~groups.clear;
				~groups = nil;
			});

		};


		~bus = {

			// Buses, following the group scheme above
			// Buses are private by default, but
			// you can provide an index for global buses
			// TODO: a way to inject buses from outside
			~template[\bus] = (
				//Type, channels, index (for global buses)
				main: [\audio, ~settings[\numChannels]],
				out: {
					try { currentEnvironment.mother[\bus][\main] } {
						[\audio, 2, 0]
					};
				}
			);


			// Add buses according to template
			~addBusesFromTemplate = {
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

			//Add a single bus, identified by key
			~addBus = { |key, rate, numChannels, index, grp|
				grp = grp ? \_default;
				 ~bus[grp][key].free; // Also if nil
				if (rate.isKindOf(Bus)) {
					~bus[grp][key] = rate;
				} {
					if (index.notNil) {
						~bus[grp][key] = Bus(rate, index, numChannels, ~server);
					} {
						~bus[grp][key] = Bus.alloc(rate, ~server, numChannels ? 2)
					};
				};
				~bus[grp][key];
			};

			// Default  action
			// If this is overridden by main envir,
			// it needs to call addBuses... at some point
			~beforeLoad = ~beforeLoad.addFunc(~addBusesFromTemplate);

			~afterFree = ~afterFree.addFunc({
				~bus.do { |ev|
					ev.do { |bus|
						bus.free;
					}
				};
				~bus.clear;
				~bus = nil;
			});

		};

		~buffer = {

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

			~settings[\defaultBufferMethod] = \read;
			~settings[\cueSize] = 65536;
			~settings[\numChannels] = 2;

			// Add buses according to template
			~addBuffersFromTemplate = {
				var template = ~template[\buffer];
				if (template.notNil) {
					~buffers ?? { ~buffers = IdentityDictionary(know:true) };
					template.keysValuesDo { |key, obj|
						~addBuffer.(key, obj);

					};
				};

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

				switch (obj[\method] ?? { ~settings[\defaultBufferPathMethod] },
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

			~generateBufferSynths = {
				if (~template[\main].notNil and: { ~template[\main].isEmpty }) {
					~template[\buffer].keys.do { |key|
						~template[\main][key] = [~settings[\defaultSynth],
							\bufnum, {~buffers[key]}];
					};
				};
			};

			~beforeInit = ~beforeInit.addFunc(~generateBufferSynths);
			~beforeLoad = ~beforeLoad.addFunc(~addBuffersFromTemplate);

			~afterFree = ~afterFree.addFunc({
				~buffers.do(_.free);
				~buffers.clear;
				~buffers = nil;
			});

		};


		~cells = {

			~loadCells = {
				~cells ?? { ~cells = IdentityDictionary(know:true) };
				~template[\cells].keysValuesDo { |k, v|
					~cells[k] = v
				};
			};

			~playCells = {
				~cells.do(_.play);
			};

			~stopCells = {
				~cells.do(_.stop);
			};

			~freeCells = {
				~cells.do(_.free);
			};


			~beforeLoad = ~beforeLoad.addFunc(~loadCells);

			~beforePlay = ~beforePlay.addFunc(~playCells);
			~beforeStop = ~beforeStop.addFunc(~playCells);
			~afterFree = ~afterFree.addFunc(~freeCells);

		};


		// A ctl is a synth + bus, often playing in a ctl group
		~ctl = {
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
		};

		// Synth related methods: FX, Ctl,
		~synth = {

			~template[\main] = IdentityDictionary();

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

				//TODO later not hardcode this,
				//Make it a part of template
				~addNodeMap.(\level, \main);

			};

			~prSynthTemplateLoop = { |group, callback|
				~template[group] !? (_.keysValuesDo({ |key, args|
					var synth;
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

			// Add volume-controlling synth
			// Set a

			//TODO later not hardcode this
			~prAddVolume = { |args|
				// This starts fading when playing synth, so it needs to start in ~play
				~prPlaySynth.(\level, \main,
					"cellMixer_%".format(~settings[\numChannels]).asSymbol,
					(fadetime: {~settings[\fadeIn]},
						out: {~bus.out}, in: {~bus.main}
					)
				);
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

			~afterInit = ~afterInit.addFunc(~addSynthNodeMap);
			~beforePlay = ~beforePlay.addFunc(~addSynthsFromTemplate);
			~beforePlay = ~beforePlay.addFunc(~prAddVolume);
			~afterPlay = ~afterPlay.addFunc(~syncSynthNodeMap);

			// Default stop: Call release on synths
			// and let them free the cell when done playing
			~defaultAfterStop = {
				if (~settings.releaseAfterStop) {
					~defaultGroup.release;
				}
			};

			~afterStop = ~afterStop.addFunc(~defaultAfterStop);

			~afterFree = ~afterFree.addFunc({
				~synths.clear;
				~synths = nil;
			});

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

		};

		~server = {
			//TODO add group methods

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

			~serverSync = {
				~server.sync;
			};

			~serverBootSync = {
				~server.bootSync;
			};

			//Default afterLoad action
			//If overridden, ~server.sync needs to be called
			~afterLoad = ~afterLoad.addFunc(~serverSync);
			~beforeLoad = ~beforeLoad.addFunc(~serverBootSync);

			// --- Server boot / quit ---

			~doOnServerBoot = nil;

			~doOnServerQuit = {
				currentEnvironment.freeAll;
			};

			~registerServer = {
				ServerBoot.add(currentEnvironment, ~server);
				ServerQuit.add(currentEnvironment, ~server);
			};

			~unregisterServer = {
				ServerBoot.remove(currentEnvironment, ~server);
				ServerQuit.remove(currentEnvironment, ~server);
			};

			// We call registerServer in the init hook,
			// so it's evaluated within the right envir
			~beforeInit = ~beforeInit.addFunc(~registerServer);

		};




	});

});