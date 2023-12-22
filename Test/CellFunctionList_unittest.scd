if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("CellFunctionList", thisProcess.nowExecutingPath).runScript;
	UnitTestScript.passVerbosity = UnitTestScript.brief;
};

{
	|test|

	var keys = #[one, two, three];
	var funcs = [{1}, {2}, {3}];
	var cfl = CellFunctionList();
	keys.do { |k, i|
		cfl[k] = funcs[i];
	};

	test.assert(cfl.value == funcs.collect(_.value), "Functions run in order");

	value {
		var kz, fz;
		cfl.keysValuesDo { |k, v|
			kz = kz.add(k);
			fz = fz.add(v);
		};
		test.assert((kz == keys) && (fz == funcs) , "KeysValuesDo run in order");
	};


	test.assert(cfl.includes(funcs[0]), "Includes answers true if func exists");
	test.assert(cfl.includes({}).not, "Includes answers false if func doesn't exist");

	cfl = CellFunctionList([{ |in| in.add(1) }, { |in| in.add(2) }, { |in| in.add(3) } ]);
	cfl.evaluationMode = \compose;
	test.assertEquals(cfl.value([]), #[1,2,3], "Mode 'compose' is composing the funciton list forwards");
	cfl.evaluationMode = \reduce;
	test.assertEquals(cfl.value([]), #[3,2,1], "Mode 'reduce' is composing the function list backwards");

	cfl = CellFunctionList([{ nil }, { 2 }, { 3 }, { nil }]);
	cfl.evaluationMode = \first;
	test.assertEquals(cfl.value, 2, "Mode 'first' is returning the first non-nil value");
	cfl.evaluationMode = \last;
	test.assertEquals(cfl.value, 3, "Mode 'last' is returning the last non-nil value");

	cfl = CellFunctionList([{ nil }, { nil }]);
	cfl.evaluationMode = \last;
	test.assertEquals(cfl.value, nil, "Mode 'last' is returning nil if non-nil value doesn't exist");
	cfl.evaluationMode = \first;
	test.assertEquals(cfl.value, nil, "Mode 'first' is returning nil if non-nil value doesn't exist");

}