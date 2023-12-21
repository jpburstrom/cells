CellConnectionHelper {
	classvar <globalDictionaryClasses;
	var template;
	var connections;

	*initClass {
		globalDictionaryClasses = [\Pdef, \Ndef, \Tdef,
			\Tr, \Cl, \At
		]
	}

	*new { |template|
		^super.newCopyArgs(template).init;
	}

	init {
		connections = ConnectionList();
	}

	connect { |source, targetsOrSettings|
		var settings = this.parseConnectionTargets(targetsOrSettings, source);
		settings.do { |target|
			connections.add(
				ConnectionList.make {
					this.prMakeConnection(source, target);
				}
			)
		}
	}

	disconnect {
		connections.free;
	}
	

	resolve { |sourceEnvir, targetEnvir, throw=true|
		var allConnections = this.collectConnections(template);
		^this.resolveObjectKeys(allConnections, sourceEnvir, targetEnvir, throw);
	}

	collectConnections { |object|
		var out;
		object.pairsDo({ |source, target|
			source = this.makeDictionaryListForKey(source, \source);
			target = this.makeDictionaryListForKey(target, \target);
			source.do { |src|
				target.do { |tgt|
					out = out.add(IdentityDictionary().putAll(src, tgt));
				}
			};
		});
		^out
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

	makeDictionaryListForKey { |obj, objectKey|
		case { obj.isKindOf(Dictionary) } {
			//Support for (key: array_of_keys) with common settings
			var keyValue = obj.removeAt(objectKey);
			^this.makeDictionaryListForKey(keyValue, objectKey).collect { |o|
				o.putAll(obj);
			}
		} { obj.isArray and: { obj.isString.not } } {
			^obj.collect({ |item|
				item.debug("item");
				if (item.isKindOf(Dictionary).not) {
					IdentityDictionary[objectKey.asSymbol -> item]
				} {
					item
				}
			});

		} {
			^obj = [IdentityDictionary[objectKey.asSymbol -> obj.copy]];
		};
	}



	resolveKey { |key, envir, throw=true|
		var out=key;
		envir ?? { envir = currentEnvironment };
		if (key.isString or: { key.isKindOf(Symbol) }) {
			var path;
			key = key.asString;
			path = key.split($_).collect(_.asSymbol);
			if (this.globalDictionaryClasses.includes(path[0])) {
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
}