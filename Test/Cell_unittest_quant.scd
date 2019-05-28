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
	test.assert(cell.timeToPos(\playEnd).isNil, "timeToPos is nil before play start");
	cell.play;

	test.assertFloatEquals(cell.timeToPos(\playStart), 0.0, "timeToPos playStart is 0.0 on play start");
	test.assertFloatEquals(cell.timeToPos(\playEnd), 5.0, "timeToPos playEnd equals duration on play start");

	teardown.value;
	"ok".postln;
	setup.value;
	(1..16).do { |quant|

		cell.play(argQuant: quant, argClock:TempoClock.default);
		test.assertFloatEquals(cell.timeToPos(\playStart), TempoClock.timeToNextBeat(quant), "timeToPos playStart equals TempoClock timeToNextBeat when quant = %".format(quant));
		cell.stop;
	};

	setup.value.play(2);
	test.assert(cell[\fastForward] == 2, "fastForward is stored in envir");
	test.assert(cell.getDuration == 3, "fastForward affects duration");
	test.assertFloatEquals(cell.timeToPos(\playStart), 0, "playStart is negative after ffwd");
	test.assertFloatEquals(cell.timeToPos(\playEnd), 3.0, "timeToPos reports correctly after fast forward");

	teardown.value;

	setup.value({
		~settings[\quant] = 1;
	}).play(2);
	test.assertFloatEquals(cell.timeToPos(\playStart, quantSync: true), ( TempoClock.timeToNextBeat(1)).max(0), "playStart is correct after fast forward when quant = 1");
	test.assertFloatEquals(cell.timeToPos(\playEnd, quantSync: true), 3.0 + TempoClock.timeToNextBeat(1), "playEnd is correct after fast forward when quant = 1");


	teardown.value;

	"ok".postln;
	setup.value(load:false).play(-1);
	"ok".postln;
	test.assertFloatEquals(cell.timeToPos(\playEnd), 1, "negative fastForward counts from end");
	"ok".postln;
}