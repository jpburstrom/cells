if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("CellConnectionHelper", thisProcess.nowExecutingPath).runScript;
	UnitTestScript.passVerbosity = UnitTestScript.brief;
};

{
	|test|

	var sourceEnvir = (
		unipolar: NumericControlValue(),
		freq: NumericControlValue(220, \freq),
	);

	var targetEnvir = (
		main: (
			def: (
				freq: NumericControlValue(220, \freq),
				amp: NumericControlValue(0.1, \amp),
				bipolar:  NumericControlValue(0, \bipolar),
			)
		)
	);


	Cl(\cellConnectionHelperTest, \base,
		\test, (
			something: NumericControlValue();
		)
	);

	  //Simple connectiMon
    //freq: "main_def_freq",
	c = CellConnectionHelper((freq: "main_def_freq"));

	[
		"string": ["string"],
		\symbol: [\symbol],
		1: [1],
		["one", "two"]:	["one", "two"],
		(test: "dict"): ["dict"],
		(test: ["one", "two"]): ["one", "two"],
		[(test: "one"), (test: "two")]: ["one", "two"],
	].pairsDo { |input, output|
		var msg = "Does work: Building connection template, input %".format(input.cs);
		input = c.unfoldTemplateForKey(input, \test).collect(_[\test]);
		test.assertEquals(input, output, msg);
	};
	[
		[(test: ["one", "two"]), (test: "three")]: ["one", "two", "three"],
	].pairsDo { |input, output|
		var msg = "Does not work: Nested connection template, input %".format(input.cs);
		test.assertException({
			c.unfoldTemplateForKey(input, \test).collect(_[\test])
		}, Error, msg);
	};

	test.assertEquals(c.resolveKey("freq", sourceEnvir), sourceEnvir[\freq], "Resolving local key");

	test.assertEquals(c.resolveKey("Cl_cellConnectionHelperTest_test_something", sourceEnvir), Cl(\cellConnectionHelperTest)[\test][\something], "Resolving global key");
	test.assert(c.resolveKey("Cl_cellConnectionHelperTest_test_something", sourceEnvir).notNil, "Global key is not nil");

	c.resolveTemplate(sourceEnvir, targetEnvir);
	test.assertEquals(c.resolvedTemplate[0][\source], sourceEnvir[\freq], "Symbol source resolves");
	test.assertEquals(c.resolvedTemplate[0][\target], targetEnvir[\main][\def][\freq], "String path with underscores resolves");
	c.connect;
	test.assertEquals(c.connections.size, 1, "Connect creates a connection");
	test.assertEquals(c.connections[0].size, 1, "Connections without remap creates a direct connection");
	c.disconnect;
	test.assertEquals(c.connections.size, 0, "Disconnect removes connections");

	c = CellConnectionHelper((unipolar: "main_def_freq"));
	c.resolveTemplate(sourceEnvir, targetEnvir);
	test.assertEquals(c.resolvedTemplate[0][\source], sourceEnvir[\unipolar], "Symbol source resolves");
	c.connect;
	test.assert(c.resolvedTemplate[0][\remap], "Connection between different specs sets remap to true");
	test.assertEquals(c.resolvedTemplate[0][\signal], \input, "Connection between different specs sets signal to input");
	test.assert(c.connections[0].size > 1, "Connection between different specs makes a non-direct connection");
	c.disconnect;
	test.assertEquals(c.connections.size, 0, "Disconnect removes connections");


	c = CellConnectionHelper((unipolar: (target: "main_def_freq", remap: [220, 440], signal: \hoho)));
	c.resolveTemplate(sourceEnvir, targetEnvir);
	test.assertEquals(c.resolvedTemplate[0][\target], targetEnvir[\main][\def][\freq], "Dictionary target resolves");
	test.assertEquals(c.resolvedTemplate[0][\signal], \hoho, "signal settings propagates to resolved template");
	c.connect;
	test.assertEquals(c.resolvedTemplate[0][\remap], [220, 440], "Remap setting propagates to resolved template");
	test.assertEquals(c.resolvedTemplate[0][\signal], \input, "Connection between different specs sets signal to input even if it's previously set (with a warning)");
	c.disconnect;

	c = CellConnectionHelper((unipolar: ["main_def_freq", (target: "main_def_bipolar", remap: false)]));
	c.resolveTemplate(sourceEnvir, targetEnvir);
	test.assertEquals(c.resolvedTemplate.size, 2, "Target Array creates multiple connections");
	test.assertEquals(c.resolvedTemplate[0][\target], targetEnvir[\main][\def][\freq], "First target, string inside array, resolves");
	test.assertEquals(c.resolvedTemplate[1][\target], targetEnvir[\main][\def][\bipolar], "Second target, dictionary inside array, resolves");
	c.connect;
	test.assert(c.resolvedTemplate[0][\remap], "Unipolar -> freq connection is forcing remap");
	test.assert(c.resolvedTemplate[1][\remap] == false, "Remap: false is propagated to resolved template");
	test.assert(c.resolvedTemplate[1][\signal].isNil, "Remap: false doesn't set signal");
	test.assertEquals(c.connections[1].size, 1 , "Second target, dictionary inside array, resolves");
	c.disconnect;

	c = CellConnectionHelper((unipolar: [(target: "main_def_freq", x:1), (target: "main_def_bipolar", x:2)]));
	c.resolveTemplate(sourceEnvir, targetEnvir);
	test.assert(c.resolvedTemplate[0][\x] != c.resolvedTemplate[1][\x], "Array of dictionaries propagates different values to resolved template");
	c.disconnect;

	c = CellConnectionHelper((#[unipolar, freq]: ["main_def_freq", "main_def_amp"]));
	c.resolveTemplate(sourceEnvir, targetEnvir);
	test.assertEquals(c.resolvedTemplate.size, 4, "Many-to-many connection works as expected");
	c.disconnect;
	test.assertEquals(c.resolvedTemplate.size, 4, "Many-to-many connection works as expected");
	c.disconnect;

    //Simple connection with wildcards (don't implement now)
    //freq: "main_*_freq",
    //Connection to global parameter
    //level: \Tr_master_send_main_level
    //Connection from global cv
    //At_makro_intensity: "main_def_freq"
    //Simple with objects instead of strings/symols
    //At(\makro)[\intensity]: { ~track[\main][\def][\freq] },
    //Connection with args
	/*
    //freq: (
        to: \main_def_freq,
        signal: \value, //input/value/..
        slot: \value, //input/value/..
        inRange: #[0,	 0.5, clip],
        //or prehaps more explicit
        inRangeBehavior: \filter // clip (default), filter
        outRange: ControlSpec(440, 880, \exp)
        outRange: [220, 440)
        outRange: \loFreq
        //Raw filter
        filter: {  },
        //Raw transform
        transform: { },
        collapse: 0.1,
        oneShot: true
    )
	*/
    //OTM Connection with same args
	/*
    freq: (
        to: [\main_def_freq, \main_asd_freq],
        filter: {  },
        transform: { },
        collapse: 0.1,
        oneShot: true
    )
	*/
    //OTM Connection with different args for different connections
	/*
    freq: [
        (to: \main_def_freq,
            transform: { },
        ),
        (to: [\main_def_freq, \main_asd_freq],
            transform: { },
        ),
    ]
	*/

}