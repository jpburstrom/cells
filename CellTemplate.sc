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
		rawEnvir = Environment();
		dependencies !? {
			rawEnvir.putAll(
				*dependencies.asArray.collect { |depKey| makeEnvir[depKey].value }
			);
		};
		rawEnvir = rawEnvir.make(makeFunc);
		envir = rawEnvir.copy;
		rawEnvir.keysValuesDo { |key, val|
			var deps, out;
			if (val.isFunction or: { val.isKindOf(Association) }) {
				deps = this.findDepsFor(key);
				out = val;
				if (deps.notNil and: { deps.notEmpty }) {
					// Make a function list with all dependencies in order
					// CellFunctionList is like a FunctionList where funcs can be looked up
					// by key
					out = CellFunctionList();
					deps.do { |depKey|
						out[depKey] = makeEnvir[depKey].getMethodFunc(key);
						// Assume we have an association, and add extracted function
					};
					// Assign the main function to an arbitrary key
					// We will probably not use it
					// Keys are good to be able to remove certain functions if needed
					// (eg deps which are handled from elsewhere)
					// TODO maybe need to access this from user template?
					out[\_current] = val.value;
				};
				envir[key] = out;
			}
		};
		envir;
	}

	findDepsFor { |method, out|
		var deps;
		if (rawEnvir[method].isKindOf(Association)) {
			if (rawEnvir[method].key.isNil) {
				^out
			};
			deps = rawEnvir[method].key
		} {
			// Fall back to global deps
			if (rawEnvir[method].isFunction) {
				deps = dependencies;
			};
		};
		out = [];
		deps.do { |dep|
			out = makeEnvir[dep].findDepsFor(method, out);
			if (out.includes(dep).not and: { makeEnvir[dep].getMethodFunc(method).notNil } ) {
				out = out.add(dep)
			};
		};
		^out
	}

	getMethodFunc { |method|
		var func = rawEnvir[method];
		if (func.respondsTo(\key)) {
			func = func.value;
		};
		if (func.isFunction.not) {
			func = nil;
		};
		^func;
	}

	value {
		^envir
	}
}