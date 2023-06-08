if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("CellTemplate", thisProcess.nowExecutingPath).runScript;
};

{
	|test|

	var cell, server;

	test.assert(Cell.players[\server][\templateInit].isNil, "Server has no templateInit");
	test.assert(Cell.players[\bus][\templateInit].isFunction, "Bus has templateInit");
	test.assert(Cell.players[\group][\templateInit].isFunction, "Group has templateInit");
	test.assert(Cell.players[\synth][\templateInit].isKindOf(CellFunctionList), "Synth templateInit is functionList");
	test.assert(Cell.players[\synth][\templateInit].array.size == 3, "Synth has three templateInit functions");
	test.assert(Cell.players[\synth][\templateInit].keys.includes(\group), "Synth has group templateInit");


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