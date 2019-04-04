if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("CellTemplate", thisProcess.nowExecutingPath).runScript;
};

{
	|test|

	var cell, server;

	test.assert(Cell.players[\server][\beforeInit].isNil, "Server has no beforeInit");
	test.assert(Cell.players[\bus][\beforeInit].isFunction, "Bus has beforeInit");
	test.assert(Cell.players[\group][\beforeInit].isFunction, "Group has beforeInit");
	test.assert(Cell.players[\synth][\beforeInit].isKindOf(CellFunctionList), "Synth beforeInit is functionList");
	test.assert(Cell.players[\synth][\beforeInit].array.size == 3, "Synth has three beforeInit functions");
	test.assert(Cell.players[\synth][\beforeInit].keys.includes(\group), "Synth has group beforeInit");


	#[server, bus, group, ctl, synth, buffer, disk].do { |key, i|
		cell = Cell({}, key);

		test.assert(cell[\server].notNil, "Creates server: %".format(key));
		test.assert(cell[\template].notNil, "Has template: %".format(key));

		test.assert(cell[\nodeMap].notNil, "Has nodeMap: %".format(key));

		if (i > 1) {
			test.assert(cell[\template][\group].notNil, "Has group template: %".format(key));
		};

		cell.free
	};


	server = Server("test");

	SynthDef(\silence, { |dummyParam|
		Out.ar(0, DC.ar.dup);
	}).add;

	server.waitForBoot {
		cell = Cell({~server = server}, \synth);
		cell.play;

		test.assert(cell[\groups].size == cell[\template][\group].size, "Has groups");
		test.assert(cell.envir.postln[\synths].postln.notNil, "Has synths");

		server.quit;
		server.remove;

		UnitTestScript.report;
	}



}