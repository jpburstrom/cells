CellFunctionList : FunctionList {
	var <>indexMap;
	var <evaluationMode;
	var <evaluationFunc;

	*new { |functions|
		^super.new(functions).init;
	}

	init {
		indexMap = IdentityDictionary();
	}

	evaluationMode_ { |mode|
		switch (mode,
			\reduce, {
				evaluationFunc = array.reduce('<>');
				evaluationMode = mode;
			},
			\compose, {
				evaluationFunc = array.reverse.reduce('<>');
				evaluationMode = mode;
			},
			\first, {
				evaluationFunc = { |...args|
					block { |break|
						array.do { |func, i|
							var res = func.value(*args);
							if (res.notNil) {
								break.value(res)
							}
						};
						nil
					}
				};
				evaluationMode = mode;
			},
			\last, {
				evaluationFunc = { |...args|
					block { |break|
						array.reverseDo { |func|
							var res = func.value(*args);
							if (res.notNil) {
								break.value(res)
							}
						};
						nil
					}
				};
				evaluationMode = mode;
			}, {
				if (mode.notNil and: { mode != \collect  }) {
					"CellFunctionList: mode % doesn't exist. Falling back to default (collect)".warn;
				} {
				evaluationMode = nil;
					
				};
				evaluationFunc = nil;
			}
		);
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

	size { ^array.size }

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

	value { arg ... args;
		^if (evaluationFunc.notNil) {
			evaluationFunc.valueArray(args);
		} {
			super.valueArray(args);
		}
	}
	valueArray { arg args;
		^if (evaluationFunc.notNil) {
			evaluationFunc.valueArray(args);
		} {
			super.valueArray(args);
		}
	}
	valueEnvir { arg ... args;
		^if (evaluationFunc.notNil) {
			evaluationFunc.valueArrayEnvir(args);
		} {
			super.valueArrayEnvir(args);
		}
	}
	valueArrayEnvir { arg args;
		^if (evaluationFunc.notNil) {
			evaluationFunc.valueArrayEnvir(args);
		} {
			super.valueArrayEnvir(args);
		}
	}
}
