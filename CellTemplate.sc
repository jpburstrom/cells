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
				val = FunctionList().array_(dependencies.collect { |depKey|
					makeEnvir[depKey].getMethodFunc(key);
				// Assume we have an association, and add extracted function
				}).addFunc(val.value);
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