CellFunctionList : FunctionList {
	var <>indexMap;

	*new {
		^super.new.init;
	}

	init {
		indexMap = IdentityDictionary();
	}

	put { |key, func|
		if (indexMap.[key].notNil) {
			var oldFunc = array[indexMap[key]];
			this.replaceFunc(oldFunc, func);
		} {
			this.addFunc(func);
			indexMap[key] = array.size - 1;
		}
	}

	at { |key|
		if (key.isKindOf(Symbol)) {
			^indexMap[key] !? (array[_]);
		}
	}

	removeAt { |key|
		indexMap.removeAt(key) !? { |index|
			super.removeFunc(array[index]);
		}
	}

	replaceKey { |oldKey, newKey|
		indexMap[oldKey] !? { |index|
			indexMap[newKey] = index;
			indexMap.removeAt(oldKey);
		}
	}

	removeFunc { |func|
		this.findKeyForFunc(func) !? { |key|
			indexMap[key] = nil;
		};
		super.removeFunc(func);
	}

	findKeyForFunc { |func|
		^array.indexOf(func) !? { |index|
			indexMap.findKeyForValue(index);
		}
	}

	keys {
		^indexMap.keys
	}

	keysValuesDo { |function|
		var key;
		array.do { |func, i|
			key = indexMap.findKeyForValue(i);
			if (key.notNil) {
				function.(key, func, i);
			};
		};
	}

	includes { |item|
		^if (array.notNil) {
			array.includes(item);
		} {
			false
		};
	}

	copy {
		^super.copy.indexMap_(indexMap.copy);
	}

	functionPerformList { |selector, args|
		^this.performList(selector, args);
	}

}

