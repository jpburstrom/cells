"Loading parent environment".debug;
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

			// Copy these keys to proto, to not overwrite/change them in parent
			~copyToProto = #[settings, params, template, markers, nodeMap];

			// Settings that need to be in place before
			// doing anything else
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
				quant: 1,


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

			~nodeMap = MultiLevelIdentityDictionary();

			// Template of parameters
			// that can be set during cell play
			~template[\param] = (

				// Main cell volume
				volume: { NumericControlValue(1, \db) },
				// Progress is updated when player is playing.
				// A value from 0 to 1, where 1 is total duration
				// excluding tail
				// TODO: How do we deal with infinite durations?
				progress: { NumericControlValue(0, \unipolar) }

			);

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

			~beforeInit = ~beforeInit.addFunc(~addGroupNodeMap);
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
				main: [\audio, ~settings.numChannels],
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

				~template[\bus].keysValuesDo { |key, args|
					args = args.value.asArray;
					~addBus.(key, *args);
				};
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
						~bus[grp][key] = Bus.alloc(rate, ~server, 2)
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

			~settings[\defaultBufferPathMethod] = \cueSoundFile;
			~settings[\cueSize] = 65536;
			~settings[\numChannels] = 2;

			/*
			~template[\buffer] = (
				// ~defaultBufferMethod (path)
				key: string,
				// alloc
				key: integer,
				// custom
				key: array;
			);
			*/

						// Add buses according to template
			~addBuffersFromTemplate = {
				~buffers ?? { ~buffers = IdentityDictionary(know:true) };
				//FIXME
				/*
				~template[\buffer].keysValuesDo { |key, args|
					var buf;
					case
					{ args.isKindOf(String) } {
						args = [~settings[\defaultBufferPathMethod], args];
					}
					~addBuffer.(key, *args);
				};
				*/
			};

			~beforeLoad = ~beforeLoad.addFunc(~addBuffersFromTemplate);

			~afterFree = ~afterFree.addFunc({
				~buffers.do(_.free);
				~buffers.clear;
				~buffers = nil;
			});

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

			~template[\main] = IdentityDictionary[
				\foo -> [\default]
			];

			~addSynthsFromTemplate = {
				var key, synth, args;
				~synths ?? { ~synths = IdentityDictionary(know:true) };
				~template[\group].do { |groupKey|
					~prSynthTemplateLoop.(groupKey, ~prPlaySynth);
				};

			};

			~addSynthNodeMap = {
				~template[\group].do { |groupKey|
					~prSynthTemplateLoop.(groupKey, { |group, key, synth, args|
						var map;
						map = ~addNodeMap.(group, key);
						args !? { map.putAll(args) };
					});
				};

				//TODO later not hardcode this,
				//Make it a part of template
				~addNodeMap.(\level, \volume);

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
				~prPlaySynth.(\level, \volume,
					"cellMixer_%".format(~settings.numChannels).asSymbol,
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
				// Send using default latency, to sync with patterns et al
				s.bind({
					if (synth.isSymbol) {
						out = Synth(synth, args.asPairs, ~groups[group]);
					} {
						// Assume we have a function
						out = synth.play(~groups[group], args[\out], args: args.asPairs);
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



			~beforeInit = ~beforeInit.addFunc(~addSynthNodeMap);
			~beforePlay = ~beforePlay.addFunc(~addSynthsFromTemplate);
			~beforePlay = ~beforePlay.addFunc(~prAddVolume);
			~afterPlay = ~afterPlay.addFunc(~syncSynthNodeMap);


			// Default stop: Call release on synths
			// and let them free the cell when done playing
			~defaultAfterStop = {
				if (~settings.releaseAfterStop) {
					~groups[\main].release;
				}
			};

			~afterStop = ~afterStop.addFunc(~defaultAfterStop);

			~afterFree = ~afterFree.addFunc({
				~synths.clear;
				~synths = nil;
			});

			~fadeIn = { |time|
				~set.(\level, \volume, \fadetime, time ?? { ~settings[\fadeIn] } );
				~set.(\level, \volume, \amp, ~get.(\level, \volume, \amp) ? 1);
				~set.(\level, \volume, \freeWhenDone, 0);
				currentEnvironment.play;
			};

			~fadeOut = { |time, freeWhenDone=true|
				~set.(\level, \volume, \fadetime, time ?? { ~settings[\fadeOut] });
				//Access this directly, so nodeMap is not affected
				~synths[\level][\volume].set(\amp, 0, \freeWhenDone, freeWhenDone.asInteger);
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
			~afterLoad.addFunc(~serverSync);
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

	~players = Environment.make {

		~basic = makeEnv.(nil, #[settings]);

		~synth = makeEnv.({

		},  #[settings, server, group, bus, ctl, synth]);

		~buffer = makeEnv.({
			~settings[\defaultBufferPathMethod] = \read;
			~synthName = \bufPlayer;
			~template.buffer = nil; //

		}, [\settings, \server, \group, \bus, \ctl, \synth, \buffer]);

		~disk = makeEnv.({
			~settings[\defaultBufferPathMethod] = \cueSoundFile;
			~synthName = \diskPlayer;
			~template.buffer = nil; //

		}, [\settings, \server, \group, \bus, \ctl, \synth, \buffer]);

		~stem = ~disk.deepCopy.make({
		});

		~pattern = makeEnv.({
		});

	};

});
