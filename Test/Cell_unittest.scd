if (thisThread.isKindOf(Routine).not) {
	UnitTestScript("Cell", thisProcess.nowExecutingPath).runScript;
};

{
	|test|
	var server, cell, setup, teardown;

	server = Server("test");

	setup = { |func, load=true|
		cell = Cell({
			~load = {
				~buf = Buffer.alloc(server, 1000);
				~buf2 = Buffer.alloc(server, 1000);
			};

			~freeAll = {
				~buf.free;
			};
		}.addFunc(func));
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

		setup.value(nil, false);
		test.assert(cell.checkState(\foo) == false, "checkState doesn't choke on bogus state symbol");
		test.assert(cell.checkState(\free), "Cell starts free");
		cell.load;
		test.assert(cell.checkState(\ready), "state equals ready after load");
		test.assert(cell.checkState(\ready, \playing), "checkState multiple works");
		test.assert(cell.checkState(\playing, \ready), "checkState multiple works (2)");
		cell.play;
		test.assert(cell.checkState(\playing), "state equals playing after play");
		cell.stop;
		test.assert(cell.checkState(\free), "state equals free after stop");
		teardown.value;

		// Testing free on stop

		setup.value;
		test.assert(cell[\buf].numFrames == 1000, "Buffer has correct number of frames");
		cell.stop;

		test.assert(cell[\buf].bufnum == nil, "Buffer bufnum is nil after cell stop");
		test.assert(cell[\buf2].bufnum != nil, "Unfreed bufnum is not nil after cell stop");

		value {
			var num=0;
			server.cachedBuffersDo { num = num + 1 };
			test.assert(num == 1, "Number of buffers on server is correct");
		};

		teardown.value;

		setup.value;
		cell[\freeAll] = nil;
		cell.stop;
		test.assert(cell[\buf].bufnum == nil, "Buffer is freed even when a freeAll method is not passed");
		teardown.value;

		setup.value;
		cell.free;
		test.assert(cell[\buf].bufnum == nil, "Buffer is freed on free");
		teardown.value;



		setup.value({
			~load = {};
			~stop = {
				~wasStopped = true;
			};
			~hardStop = {
				~wasHardStopped = true;
			};
		});

		cell.play;
		cell.free;
		test.assert(cell[\wasHardStopped].notNil, "Cell calls ~hardStop on free");
		test.assert(cell[\wasStopped].isNil, "Cell doesn't call ~stop on free");


		setup.value({
			~load = {};
			~stop = {
				~wasStopped = true;
			};
		});

		cell.play;
		cell.free;
		test.assert(cell[\wasStopped].notNil, "Cell calls ~stop on free, if ~hardStop is nil");

		cell.free;

		server.quit;
		server.remove;
	}

};
