if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("CellTemplate", thisProcess.nowExecutingPath).runScript;
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
			[k, v].postln;
			kz = kz.add(k);
			fz = fz.add(v);
		};
		test.assert((kz == keys) && (fz == funcs) , "KeysValuesDo run in order");
	};


	test.assert(cfl.includes(funcs[0]), "Includes answers true if func exists");
	test.assert(cfl.includes({}).not, "Includes answers false if func doesn't exist");


}