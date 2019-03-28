CellTemplate {
	var <makeFunc, <dependencies, <makeEnvir;
	// method->dependency dictionary
	var <rawEnvir;
	// cooked envir, without dictionaries
	var <envir;

	*new { |makeFunc, dependencies, makeEnvir|
		^super.newCopyArgs(makeFunc, dependencies, makeEnvir).init;
	}

	init {
		// By default, bind environment to current
		makeEnvir ?? { makeEnvir = currentEnvironment };
		this.build;
	}

	build {
		dependencies.postln;
		rawEnvir = Environment();
		dependencies !? {
			rawEnvir.putAll(
				*dependencies.asArray.collect { |depKey| makeEnvir[depKey].value }
			);
		};
		rawEnvir = rawEnvir.make(makeFunc);
		envir = rawEnvir.copy;
		rawEnvir.keysValuesDo { |key, val|
			var deps = this.findDepsFor(key);,
			out = val;
			if (deps.notEmpty) {
				// Make a function list with all dependencies in order
				// CellFunctionList is like a FunctionList where funcs can be looked up
				// by key
				out = CellFunctionList();
				deps.do { |depKey|
					// First thing: make everything from dependency
					if (deps.includes(depKey).not) {
						rawEnvir.use(makeEnvir[depKey].makeFunc);
					};
					out[depKey] = makeEnvir[depKey].getMethodFunc(key);
				// Assume we have an association, and add extracted function
				};
				// Assign the main function to an arbitrary key
				// We will probably not use it
				// Keys are good to be able to remove certain functions if needed
				// (eg deps which are handled from elsewhere)
				// TODO maybe need to access this from user template?
				val[\_current] = val.value;
			};
			envir[key] = out;
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