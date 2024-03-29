CellConnectionHelper : CellTemplateHelper {
	classvar <globalDictionaryClasses;
	var <connections;

	*initClass {
		globalDictionaryClasses = [\Pdef, \Ndef, \Tdef,
			\Tr, \Cl, \At
		]
	}

	init {
		keyLabel = \source;
		valueLabel = \target;
		connections = List();
	}

	connect {
		//TODO this could be nil if no connections are made?
		if (resolvedTemplate == false) {
			Error("CellConnectionHelper: template not resolved").throw;
		};
		if (connections.notEmpty) {
			"CellConnectionHelper: Already connected".warn;
			^this
		};
		resolvedTemplate.do { |settings|
			connections.add(
				ConnectionList.make {
					this.makeConnection(settings);
				}
			)
		}
	}

	disconnect {
		connections.do(_.free);
		connections = nil;
	}
	

	resolveTemplate { |sourceEnvir, targetEnvir, throw=true|
		var allConnections = this.collectTemplate(template);
		^resolvedTemplate = this.resolveObjectKeys(allConnections, sourceEnvir, targetEnvir, throw);
	}
	/*

	*/
	resolveObjectKeys { |object, sourceEnvir, targetEnvir, throw=true|
		object.do { |dict, index|
			dict[\source] = this.resolveKey(dict[\source], sourceEnvir, throw);
			dict[\target] = this.resolveKey(dict[\target], targetEnvir, throw);
		};
		^object
	}

	resolveKey { |key, envir, throw=true|
		var out=key;
		envir ?? { envir = currentEnvironment };
		if (key.isString or: { key.isKindOf(Symbol) }) {
			var path;
			key = key.asString;
			path = key.split($_).collect(_.asSymbol);
			if (this.class.globalDictionaryClasses.includes(path[0])) {
				var cl = path.removeAt(0);
				var k = path.removeAt(0);
				envir = cl.asClass.new(k);
			};
			out = envir;
			path.do { |item|
				out = out[item];
				if (out.isNil) {
					if (throw) {
						Error("Can't resolve target key %".format(key)).throw;
					} {
						warn("Can't resolve target key %".format(key));
						^this
					}
				}
			};
		};
		^out
	}

	makeConnection { |settings|
		var signal = settings[\source];
		var target = settings[\target];
		var slot, connection;
		//If target spec exists, remap by default
		//But don't remap to the same spec
		//We're using a local remap variable so we can re-evaluate settings[\remap] each connection
		if (settings[\remap].isNil) {
			var targetSpec = target.tryPerform(\spec);
			settings[\remap] = targetSpec.notNil and: { targetSpec != signal.tryPerform(\spec) };
		};
		if (settings[\remap] != false) {
			if (settings[\signal].notNil and: { settings[\signal] != \input  }) {
				"MakroParam connection: Remap is set, forcing 'input' signal. Remove 'signal' from settings to avoid this warning.".warn
			};
			settings[\signal] = \input;
		};
		if (settings[\signal].notNil) {
			signal = signal.signal(settings[\signal]);
		};
		if (#[value, input, nil].includes(settings[\slot])) {
			slot = target.valueSlot(settings[\slot] ? \value);
		} {
			slot = target.methodSlot(settings[\slot]);
		};
		connection = signal.connectTo(slot);
		settings[\filter] !? { |filter|
			if (filter.isArray) {
				//Assuming array
				connection.filter("|obj, what, val| val.inclusivelyBetween(%, %);".format(*filter).compile);
			} {
				connection.filter(filter);
			}
		};
		settings[\clip] !? { |inRange|
			connection.transform("|obj, what, val| [obj, what, val.clip(%, %)];".format(*inRange).compile);
		};
		if (settings[\remap] != false) {
			var spec = settings[\remap];
			if ( spec == true ) {
				spec = target.spec;
			} {
				spec = spec.asSpec;
			};
			connection.transform({ |obj, what, val| [obj, what, spec.map(val)] });
		};
		settings[\transform] !? { |transform|
			if (transform.isString) {
				connection.transform("|obj, what, val|
							[obj, what, %];
						".format(transform).compile)
			} {
				connection.transform(transform);
			}
		};
		settings[\collapse] !? { |seconds|
			connection.collapse(seconds);
		};
		^connection;
	}
}