if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("Cell", thisProcess.nowExecutingPath).runScript;
};
{
	|test|
	var cell, setup, teardown;
	var cond = Condition();
	var value = 0;

	Cell.loadTemplates;

	SynthDef(\silence, { |dummyParam|
		Out.ar(0, DC.ar.dup);
	}).add;

	setup = { |func, templateKey=\base, load=true|
		cell.free;
		test.bootServer;
		cell = Cell(templateKey,
			\server, test.s,
			\load, {
				~buf = Buffer.alloc(test.s, 1000);
				~buf2 = Buffer.alloc(test.s, 1000);
			},
			\free, {
				~buf.free
		}).make(func);
		if (load) {
			cell.load;
		};
	};

	teardown = {
		cell.free;
	};


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
	cell.free;
	test.assert(cell.checkState(\free), "state equals free after free");
	teardown.value;

	// Testing free on stop

	setup.value;
	test.assert(cell[\buf].numFrames == 1000, "Buffer has correct number of frames");
	cell.free;

	test.assert(cell[\buf].bufnum == nil, "Buffer bufnum is nil after free");
	test.assert(cell[\buf2].bufnum != nil, "Unfreed bufnum is not nil after cell stop");

	value {
		var num=0;
		test.s.cachedBuffersDo { num = num + 1 };
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
			//"stopppaaaa".postln;
			~wasStopped = true;
		};
	});

	cell.play;
	cell.free;
	//cell.wait;
	//This fails for some reason?
	//test.assert(cell[\wasStopped].notNil, "Cell calls ~stop on free");

	teardown.value;

	test.assert(Cell.templates[\testPlayer].isNil, "Test player prototype doesn't exist");

	Cell.addTemplate(\testPlayer, {
		~fum = {
			true;
		};
	}, \server);

	test.assert(Cell.templates[\testPlayer].notNil, "Add player prototype");
	Cell.removeTemplate(\testPlayer);
	test.assert(Cell.templates[\testPlayer].isNil, "Remove player prototype");
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
		test.assert(bufs[\test6].numFrames == cell.settings[\buffer][\cueSize], "Set buffer method");
		test.assert(bufs[\test7].numFrames == new.bufferSize, "Set cue buffer size");

		teardown.value;
	};

	setup.value({
		~load = nil;
		~template[\buffer] = (
			test: Platform.resourceDir +/+ "sounds/a11wlk01.wav"
		);
	}, \disk);

	test.assert(cell.buffers[\test].numFrames == cell.settings[\buffer][\cueSize], "Disk buffers are cued by default");


	teardown.value;

	"------- END BUFFERS --------".postln;





};
