CellFunctionList : FunctionList {
	var indexMap;

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

}

