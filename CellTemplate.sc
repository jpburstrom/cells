CellTemplate {
	var <>makeFunc, <>makeEnvir;
	// Global dependencies
	var <dependencies;
	// method->dependency dictionary
	var <rawEnvir;
	// cooked envir, without dictionaries
	var <envir;

	*new { |makeFunc, makeEnvir|
		^super.newCopyArgs(makeFunc, makeEnvir).init;
	}

	init {
		// By default, bind environment to current
		makeEnvir ?? { makeEnvir = currentEnvironment };
		this.build;
	}

	build {
		dependencies.clear;
		rawEnvir = Environment.make(makeFunc);
		envir = Environment();
		rawEnvir.keysValuesDo { |key, val|
			var out;
			dependencies = this.findDepsFor(key);
			if (dependencies.notEmpty) {

				// Make a function list with all dependencies in order
				// CellFuncitonList is like a FunctionList where funcs can be looked up
				// by key
				val = CellFunctionList();
				dependencies.do { |depKey|
					val[depKey] = makeEnvir[depKey].getMethodFunc(key);
				// Assume we have an association, and add extracted function
				};
				// Assign the main function to an arbitrary key
				// We will probably not use it
				// Keys are good to be able to remove certain functions if needed
				// (eg deps which are handled from elsewhere)
				val[\_current] = val.value;
			};
			envir[key] = val;
		};
		envir;
	}

	findDepsFor { |method, out|
		out = out ?? { [] };
		if (rawEnvir[method].isKindOf(Association)) {
			rawEnvir[method].key.do { |dep|
				makeEnvir[dep].findDepsFor(method, out);
				if (out.includes(dep).not) {
					out = out.add(dep)
				};
			};
		};
		^out
	}

	getMethodFunc { |method|
		var func = rawEnvir[method];
		if (func.respondsTo(\key)) {
			func = func.value;
		};
		^func;
	}

	value {
		^envir
	}
}