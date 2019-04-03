CellTemplate {
	var <template, <dependencies, <makeEnvir;
	// method->dependency dictionary
	var <rawEnvir;
	// cooked envir, without dictionaries
	var <envir;

	*new { |template, dependencies, makeEnvir|
		if (template.isFunction) {
			template = Environment.make(template);
		};
		^super.newCopyArgs(template, dependencies, makeEnvir).init;
	}

	init {
		// By default, bind environment to current
		makeEnvir ?? { makeEnvir = currentEnvironment };
		this.build;
	}

	build {

		rawEnvir = Environment();

		//Loop over dependencies, and put all values from them into rawEnvir
		dependencies !? {
			rawEnvir.putAll(
				*dependencies.asArray.collect { |depKey| makeEnvir[depKey].value }
			);
		};

		rawEnvir = rawEnvir.putAll(template);
		rawEnvir.make {
			template[\build].value;
		};
		envir = rawEnvir.copy;

		// Loop over makeFunc-defined keys, and see if any of them needs to turn into
		// a FunctionList
		template.keys.reject(_==\build).do { |key|
			var val = rawEnvir[key];
			if (this.prMightHaveDeps(val)) {
				// If func is defined, use that. Otherwise fallback to val
				var deps = this.findDepsFor(key);
				if (val.isKindOf(Association)) {
					val = val.value;
				};
				if (deps.notEmpty) {
					var out;
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
					out[\_current] = val;
					envir[key] = out;
				} {
					envir[key] = val;
				};
			} {
				// If func is defined, we have unpacked an association,
				// so we need to update the envir
				if (val.isKindOf(Association)) {
					envir[key] = val.value;
				};
			}
		};

	}

	prUnpackFunction { |thing|
		if (thing.isKindOf(Association)) {
			^thing.value;
		} {
			^thing
		}
	}

	prMightHaveDeps { |thing|
		if (thing.isKindOf(Association))  {
			^thing.key.notNil && thing.value.isFunction
		} {
			^dependencies.notNil && thing.isFunction
		};
	}

	findDepsFor { |method, out|
		var deps, thing;
		thing = rawEnvir[method];
		if (thing.isKindOf(Association)) {
			deps = thing.key
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