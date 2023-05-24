if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("Cell", thisProcess.nowExecutingPath).runScript;
};


{

	|test|
	var server, cell, setup, teardown;
	var cond = Condition();
	var value = 0;

	Cell.loadPlayerTemplates;


	server = Server("test");
	server.options.numInputBusChannels = 0;
	// server.bootSync;

	SynthDef(\silence, { |dummyParam|
		Out.ar(0, DC.ar.dup);
	}).add;

	setup = { |func, playerKey, load=true|
		cell.free;
		cell = Cell({
			~server = server;
			~settings[\duration] = 5;
		}.addFunc(func), playerKey).name_("test");
		if (load) {
			cell.load;
		};
		cell
	};

	teardown = {
		cell.free;
		server.freeAllBuffers;
		// server.sync;
	};


	setup.value;
	test.assertFloatEquals(cell.timeToPos(\playEnd), 5, "timeToPos works before play start");
	0.1.wait;
	test.assertFloatEquals(cell.timeToPos(\playEnd), 5, "timeToPos is not advanced before play start");
	cell.play;

	test.assertFloatEquals(cell.timeToPos(\playStart), 0.0, "timeToPos playStart is 0.0 on play start");
	test.assertFloatEquals(cell.timeToPos(\playEnd), 5.0, "timeToPos playEnd equals duration on play start");

	teardown.value;
	setup.value;
	(1..16).do { |quant|

		cell.play(argQuant: quant, argClock:TempoClock.default);
		test.assertFloatEquals(cell.timeToPos(\playStart), TempoClock.timeToNextBeat(quant), "timeToPos playStart equals TempoClock timeToNextBeat when quant = %".format(quant));
		cell.stop;
	};

	setup.value.play(2);
	test.assert(cell[\fastForward] == 2, "fastForward is stored in envir");
	test.assert(cell.getDuration == 5, "fastForward doesn't affect duration");
	test.assertFloatEquals(cell.timeToPos(\playStart), -2, "playStart is negative after ffwd");
	test.assertFloatEquals(cell.timeToPos(\playEnd), 3.0, "timeToPos reports correctly after fast forward");

	teardown.value;

	setup.value({
		~settings[\quant] = 1;
	}).play(2);

	//FIXME this doesn't work
	/*
	test.assertFloatEquals(cell.timeToPos(\playStart, quantSync: true), ( TempoClock.timeToNextBeat(1)).max(0), "playStart is correct after fast forward when quant = 1");
	*/
	test.assertFloatEquals(cell.timeToPos(\playEnd, quantSync: true), 3.0 + TempoClock.timeToNextBeat(1), "playEnd is correct after fast forward when quant = 1");


	teardown.value;

	setup.value(load:false).play(-1);
	test.assertFloatEquals(cell.timeToPos(\playEnd), 1, "negative fastForward counts from end");

	teardown.value;

	setup.value({
		~settings[\tempo] = 120;
		~settings[\duration] = 60;
		~pattern = Pbind();
	}, \pattern);

	test.assertFloatEquals(cell.timeToPos(\end), 60, "Pattern time to end is right");

	cell.play(30);

	test.assertFloatEquals(cell.timeToPos(\playEnd), 30, "Pattern time to end after ffwd");

	teardown.value;

}