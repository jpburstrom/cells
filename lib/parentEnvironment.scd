"Loading parent environment".debug;
z = Environment.make({
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

			// Settings that need to be in place before
			// doing anything else
			~settings = (
				//Number of out channels
				numChannels: 2,


				// --- DURATIONS ---
				// Total cell duration
				duration: inf,
				// Duration of tail
				// Time until silent after calling .stop, or after ~duration,
				// whatever happens first.
				// After ~tailDuration it should be safe for player to free itself
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
				fadeIn: nil,
				// Curve of fadeIn envelope - only float?
				fadeInCurve: 8,
				// Fade out duration. This overrides tailDuration.
				fadeOut: nil,
				// Curve
				fadeOutCurve: -8

			);


			// Dictionary of markers
			// label -> time
			// Time can be a single float
			// or an array of floats
			// (for onsets, phrases etc)
			~markers = nil;

			// We don't set params here, but in proto object

			~params = nil;

			// Template of parameters
			// that can be set during cell play
			~paramTemplate = (

				// Main cell volume
				volume: { NumericControlValue(1, \db) },
				// Progress is updated when player is playing.
				// A value from 0 to 1, where 1 is total duration
				// excluding tail
				// TODO: How do we deal with infinite durations?
				progress: { NumericControlValue(0, \unipolar) }

			);

		};

		// Methods + default settings for groups
		~group = {
			// Default group order
			// TODO: nested groups, if needed
			~groupTemplate = #[ctl, main, fx, level];

			// All groups end up in the groups envir
			// The envir should not be placed in the parent envir
			// So we create it as a part of ~addGroups
			~addGroupsFromTemplate = {
				~groups ?? { ~groups = () };
				~groupTemplate.do { |key|
					~addGroup.value(key);
				};
			};

			// Default beforePlay action
			// If this is overridden by main envir,
			// it needs to call addGroups... at some point
			~beforePlay = ~beforePlay.addFunc(~addGroupsFromTemplate);

			~addGroup = { |key, parent|
				~groups[key] !? (_.free);
				//If parent is set, use that
				parent = parent ?? {
					// Otherwise, use parentGroup. If nil,
					// it defaults to Group(1) (nil.asTarget)
					~groups[\parentGroup]
				};
				~groups[key] = Group(parent);
			};

			~afterFree = ~afterFree.addFunc({
				~groups.clear;
			});

		};


		~bus = {

			// Buses, following the group scheme above
			// Buses are private by default, but
			// you can provide an index for global buses
			// TODO: a way to inject buses from outside
			~busTemplate = (
				//Type, channels, index (for global buses)
				main: [\audio, ~settings.numChannels],
				out: [\audio, 2, 0]
			);


			// Add buses according to template
			~addBusesFromTemplate = {
				~bus ?? { ~bus = () };
				~busTemplate.keysValuesDo { |key, args|
					~addBus.(key, *args);
				};
			};

			//Add a single bus, identified by key
			~addBus = { |key, rate, numChannels, index|
				~bus[key] !? (_.free);
				if (index.notNil) {
					~bus[key] = Bus(rate, index, numChannels, ~server);
				} {
					~bus[key] = Bus.alloc(rate, ~server, 2)
				};
				~bus[key];
			};

			// Default  action
			// If this is overridden by main envir,
			// it needs to call addBuses... at some point
			~beforeLoad = ~beforeLoad.addFunc(~addBusesFromTemplate);

			~afterFree = ~afterFree.addFunc({
				~bus.clear;
			});

		};

		~buffer = {

			~settings[\defaultBufferPathMethod] = \cueSoundFile;
			~settings[\cueSize] = 65536;
			~settings[\numChannels] = 2;

			/*
			~bufferTemplate = (
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
				~buffers ?? { ~buffers = () };
				//FIXME
				/*
				~bufferTemplate.keysValuesDo { |key, args|
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

		};


		// A ctl is a synth + bus, often playing in a ctl group
		~ctl = {
			// Get bus from ctl key
			~ctlBus = { |key|
				~bus[~prFormatCtlKey.(key)];
			};

			// Get a kr player from ctl key
			~ctlKr = { |key|
				var bus = ~bus[~prFormatCtlKey.(key)];
				In.kr(bus, bus.numChannels);
			};

			// Get a pattern from ctl key
			// Stolen from Pkr (BenoitLib)
			~ctlPattern = { |key|
				var last = 0, check;
				key = ~prFormatCtlKey.(key);
				check = { ~server.hasShmInterface }.try;

				check.if ({
					^Pfunc({ ~bus[key].getSynchronous() });
				}, {
					"No shared memory interface detected".warn;
					~bus[key].get({|v| last = v;});
					^Pfunc({ ~bus[key].get({ |v| last = v; }); last });
				});
			};

			~prFormatCtlKey = { |key|
				"ctl_%".format(key).asSymbol;
			};

			// Add control synth (LFO etc)
			~addCtl = { |key, synth, args, numChannels=1|
				var bus = ~addBus.(~prFormatCtlKey.(key), \control, numChannels);
				args[\out] = bus.index;
				~prPlaySynth.(\ctl, \ctl, synth, args);
			};
		};

		~timedDuration = {
		};


		// Synth related methods: FX, Ctl,
		~synth = {

			// Keeper of synths
			~synths = Set();

			// Callback for synth.onFree
			// Removes synth from ~synths set
			// If all synths have ended,
			// waits for ~tailDuration and then calls parent.free
			~onSynthFree = { |syn|
				~synths.remove(syn);
				if (~synths.isEmpty) {
					currentEnvironment.free;
				}
			};

			// Add synth
			~addSynth = { |synth, args|
				~prPlaySynth.(\synth, \main, synth, args).onFree(~onSynthFree.inEnvir);
			};

			// Add effect synth
			~addFx = { |synth, args|
				~prPlaySynth.(\fx, \fx, synth, args);
			};

			// Add volume-controlling synth
			// Set a
			~addVolume = { |args|
				// This starts fading when playing synth, so it needs to start in ~play
				~prPlaySynth.(\synth, \level, "cellMixer_%".format(~settings.numChannels).asSymbol, args);
			};

			// Helper method for adding synths
			~prPlaySynth = { |type, group, synth, args|
				args = ~addDefaultArgs.(type, args);
				// Use default latency.
				s.bind {
					if (synth.isSymbol) {
						~synths.add(Synth(synth, args, ~groups[group]));
					} {
						// Assume we have a function
						~synths.add(synth.play(~groups[group], args[\out], args: args.asPairs));
					}
				}
			};

			// Add default argument for different kinds of synths
			// Right now only for out bus
			~addDefaultArgs = { |key, args|
				var out = (out: ~bus.main);
				out = switch(key,
					\synth, out,
					\fx, out,
					\ctl, out
				);
				// Overwrite defaults with args
				args !? { out.putAll(args) };
				out
			};
		};

		~server = {
			//TODO add group methods

			//FIXME we should not hardcode server here
			//Use function ?
			~server = Server.default;

			// Default is ~server.latency
			~latency = nil;

			// Things to do on server boot
			// FIXME: Cell.doOnServerBoot
			~doOnServerBoot.addFunc(~loadSynthDefs);

			//Default afterLoad action
			//If overridden, ~server.sync needs to be called
			~afterLoad.addFunc({
				~server.sync;
			});

			~beforeLoad = ~beforeLoad.addFunc({
				~server.waitForBoot;
			});

		};




	});

	~players = Environment.make {

		~synth = makeEnv.({
			~synthName = \default;
			~synthArgs = [];
			~duration = 1;

			~play = { |cell|
				~addSynth.(~synthName, ~synthArgs);
				fork {
					~duration.wait;
					cell.stop;
				};
			};

		},  [\settings, \server, \group, \bus, \ctl, \synth]);

		~synth = makeEnv.({
			~synthName = \default;
			~synthArgs = [];
			~duration = 1;

			~play = { |cell|
				~addSynth.(~synthName, ~synthArgs);
				fork {
					~duration.wait;
					cell.stop;
				};
			};

			~stop = { |cond|
				~server.bind {
					// Release synth.
					// Synths will take care of freeing the thing
					~synths.do(_.release);
				};
			};

		},  [\settings, \server, \group, \bus, \ctl, \synth]);

		~buffer = makeEnv.({
			~settings[\defaultBufferPathMethod] = \read;
			~synthName = \bufPlayer;
			~bufferTemplate = nil; //

		}, [\settings, \server, \group, \bus, \ctl, \synth, \buffer]);

		~disk = makeEnv.({
			~settings[\defaultBufferPathMethod] = \cueSoundFile;
			~synthName = \diskPlayer;
			~bufferTemplate = nil; //

		}, [\settings, \server, \group, \bus, \ctl, \synth, \buffer]);

		~stem = ~disk.deepCopy.make({
		});

		~pattern = makeEnv.({
		});

	};

});