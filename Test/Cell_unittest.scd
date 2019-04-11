if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("Cell", thisProcess.nowExecutingPath).runScript;
};

{
	|test|
	var server, cell, setup, mother, teardown;
	var cond = Condition();
	var value = 0;

	Cell.loadPlayerTemplates;


	server = Server("test");

	SynthDef(\silence, { |dummyParam|
		Out.ar(0, DC.ar.dup);
	}).add;

	setup = { |func, playerKey, load=true|
		cell.free;
		cell = Cell({
			~server = server;
			~load = {
				~buf = Buffer.alloc(server, 1000);
				~buf2 = Buffer.alloc(server, 1000);
			};

			~freeAll = ~freeAll.addFunc({
				~buf.free;
			});
		}.addFunc(func), playerKey).name_("test");
		if (load) {
			cell.load;
		};
	};

	teardown = {
		cell.free;
		server.freeAllBuffers;
		server.sync;
	};


	server.waitForBoot {

		setup.value(load:false);
		test.assert(cell.checkState(\foo) == false, "checkState doesn't choke on bogus state symbol");
		test.assert(cell.checkState(\free), "Cell starts free");
		cell.load;
		test.assert(cell.checkState(\ready), "state equals ready after load");
		test.assert(cell.checkState(\ready, \playing), "checkState multiple works");
		test.assert(cell.checkState(\playing, \ready), "checkState multiple works (2)");
		cell.play;
		test.assert(cell.checkState(\playing), "state equals playing after play");
		cell.stop;
		test.assert(cell.checkState(\stopped), "state equals stopped after stop");
		cell.freeAll;
		test.assert(cell.checkState(\free), "state equals free after freeAll");
		teardown.value;

		// Testing free on stop

		setup.value;
		test.assert(cell[\buf].numFrames == 1000, "Buffer has correct number of frames");
		cell.freeAll;

		test.assert(cell[\buf].bufnum == nil, "Buffer bufnum is nil after freeAll");
		test.assert(cell[\buf2].bufnum != nil, "Unfreed bufnum is not nil after cell stop");

		value {
			var num=0;
			server.cachedBuffersDo { num = num + 1 };
			test.assert(num == 1, "Number of buffers on server is correct");
		};

		teardown.value;

		/* This doesn't work, since ~freeAll is defined in parent envir
		setup.value;
		cell[\freeAll] = nil;
		cell.free;
		test.assert(cell[\buf].bufnum == nil, "Buffer is freed even when a freeAll method is not passed");
		teardown.value;
		*/

		setup.value;
		cell.free;
		test.assert(cell[\buf].bufnum == nil, "Buffer is freed on free");
		teardown.value;

		setup.value({
			~load = {};
			~stop = {
				~wasStopped = true;
			};
		});

		cell.play;
		cell.free;
		test.assert(cell[\wasStopped].notNil, "Cell calls ~stop on free, if ~hardStop is nil");

		teardown.value;

		test.assert(Cell.players[\testPlayer].isNil, "Test player prototype doesn't exist");

		Cell.addPlayer(\testPlayer, (
			fum: {
				true;
			};
		), \server);

		test.assert(Cell.players[\testPlayer].notNil, "Add player prototype");

		test.assert(Cell.players[\testPlayer][\server].notNil, "Add server mixin");

		Cell.removePlayer(\testPlayer);

		test.assert(Cell.players[\testPlayer].isNil, "Remove player prototype");


		teardown.value;

		"------ CELL HIERARCHY ------".postln;

		// --- Mother test 1 ---

		mother = Cell().name_("mother");
		setup.value;

		mother[\baby] = cell;
		mother.addChildren(\baby, cell);

		test.assert(mother.children.includes(cell), "Adding children");
		test.assert(cell.mother == mother,  "Adding children sets mother in child");

		mother.free;

		test.assert(mother.children.size == 0, "Removing children on free");
		test.assert(cell.mother.isNil,  "Freeing mother removes ref in child");

		teardown.value;

		// --- Mother test 2 ---

		mother = Cell({ ~template[\main] = (); ~server = server }, \synth).name_("mother");
		setup.value({ ~template[\main] = (foo: [\silence]);  ~server = server }, \synth, false);


		cell.setMother(mother, \baby);
		test.assert(mother.children.includes(cell), "setMother with key adds child to mother");
		test.assert(cell.mother == mother, "setMother with key sets mother");

		mother.play;
		cell.play;
		// server.queryAllNodes;

		test.assert(cell.bus[\out] == mother.bus[\main], "Child out bus is mother main bus");
		test.assert(cell.parentGroup == mother.groups[\main], "Child parentGroup is mother main group");


		mother.removeChildren(\baby);
		test.assert(mother.children.includes(cell).not, "removeChildren");
		test.assert(cell.mother.isNil, "removeChildren unsets mother in child");

		value = 0;
		cell.set(\main, \foo, \dummyParam, 999);
		server.latency.wait; // Wait until node is playing

		cell.synths[\main][\foo].get(\dummyParam, { |val|
			value = val;
			cond.unhang;
		});
		cond.hang;
		test.assert(value == 999, "Set sets synth value");
		value = 0;
		cell.set(\group, \main, \dummyParam, 998);
		cell.synths[\main][\foo].get(\dummyParam, { |val|
			value = val;
			cond.unhang;
		});
		cond.hang;
		test.assert(value == 998, "Group set sets synth value");
		teardown.value;
		mother.free;

		setup.value({ ~template[\main] = (foo: [\silence]);  ~server = server }, \synth, false);
		cell.set(\main, \foo, \dummyParam, 998);
		cell.play;
		// Need to wait for node to appear
		server.latency.wait;
		cell.synths[\main][\foo].get(\dummyParam, { |val|
			value = val;
			cond.unhang;
		});
		cond.hang;
		test.assert(value == 998, "Values set with .set are sent to synths on play");
		teardown.value;

		setup.value({ ~template[\main] = (foo: [\silence]);  ~server = server }, \synth, false);

		cell.set(\group, \main, \dummyParam, 997);
		cell.play;
		// Need to wait for node to appear
		server.latency.wait;
		cell.synths[\main][\foo].get(\dummyParam, { |val|
			value = val;
			cond.unhang;
		});
		cond.hang;
		test.assert(value == 997, "Values set with .set are sent to groups on play");
		teardown.value;

		"------- BUFFERS --------".postln;
		value {
			var bufs, numFrames, duration;
			var new = (
				startTime: 0.5,
				duration: 0.25,
				startFrame: 1000,
				numFrames: 50,
				bufferSize: 32768,
			);
			setup.value({
				var path = Platform.resourceDir +/+ "sounds/a11wlk01.wav";
				~load = nil;
				~template[\buffer] = (
					test1: path,
					test2: (
						path: path,
						startTime:new.startTime,
					),
					test3: (
						path: path,
						duration: new.duration,
					),
					test4: (
						path: path,
						startFrame: new.startFrame
					),
					test5: (
						path: path,
						numFrames: new.numFrames
					),
					test6: (
						path: path,
						method: \cueSoundFile
					),
					test7: (
						path: path,
						method: \cueSoundFile,
						bufferSize: new.bufferSize
					)

				);

			}, \buffer);


			bufs = cell.buffers;
			numFrames = bufs[\test1].numFrames;
			duration = bufs[\test1].duration;
			test.assert(numFrames.notNil, "Buffer template value can be string");
			test.assert(bufs[\test2].duration == (duration - new.startTime), "Set buffer startTime");
			test.assert(bufs[\test3].duration == new.duration, "Set buffer duration");
			test.assert(bufs[\test4].numFrames == (numFrames - new.startFrame), "Set buffer startFrame");
			test.assert(bufs[\test5].numFrames == new.numFrames, "Set buffer numFrames");
			test.assert(bufs[\test6].numFrames == cell.settings[\cueSize], "Set buffer method");
			test.assert(bufs[\test7].numFrames == new.bufferSize, "Set cue buffer size");

			teardown.value;
		};

		setup.value({
			~load = nil;
			~template[\buffer] = (
				test: Platform.resourceDir +/+ "sounds/a11wlk01.wav"
			);
		}, \disk);

		test.assert(cell.buffers[\test].numFrames == cell.settings[\cueSize], "Disk buffers are cued by default");


		teardown.value;

		"------- END BUFFERS --------".postln;

		server.quit;
		server.remove;

		UnitTestScript.report;



	}

};
