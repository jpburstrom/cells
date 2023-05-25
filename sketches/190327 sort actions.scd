~parentEnvironment = ().make {
	~players = ();
	~playerTemplates = ();
};

(
//Add player
Cell.addTemplate { |key, func, deps|
	parentEnvironment.playerTemplates[key] = deps -> func;
	this.buildPlayer(key);
}
)

(
~templates = ().make {
	~server = ().make {
		~load = {
			"Load server".postln
		}
	};
	~bus = ().make {
		//Key could also be an array
		~load = \server -> {
			"Load bus".postln;
		};
	};
	~group = ().make {
		//Key could also be an array
		~load = [\server] -> {
			"Load group".postln;
		};
	};
	~synth = ().make {
		//Key could also be an array
		~load = [\bus, \group] -> {
			"Load syn".postln;
		};
	};
};
)

dep1 -> dep2
dep1, dep2 -> dep3

(
// Dictionary of key -> dep for each action
var deps = ~templates.keys.collectAs((_->List()), IdentityDictionary);
// partial keys
var keys = ~templates.keys.asArray;
// action functions
var funcs;
keys.do{ |k|
	var obj = ~templates[k];
	var priority, func = obj[\load];
	// If function is association, add dependency to deps under key [k]
	if (func.respondsTo(\key)) {
		deps[k].addAll(func.key);
		func = func.value;
	};
	// Append function to array
	funcs = funcs.add(func);
};
// Order functions. Let a come before b if b depends on a
funcs = funcs[keys.order({ |a, b|
	deps[b].includes(a)
})];

// This is the cooked load function
f = FunctionList().array_(funcs)

)
