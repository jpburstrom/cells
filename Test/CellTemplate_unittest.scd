if (thisThread.isKindOf(Routine).not) {
	UnitTestScript.reset;
	UnitTestScript("CellTemplate", thisProcess.nowExecutingPath).runScript;
};
{
	|test|

	var template;
	var env = ();

	env[\server] = CellTemplate({
		~serverVariable = 23;
		~serverSpecificMethod = {};
		~overriddenMethod = { "hello".postln };
		~load = {
			"Load server".postln
		}
	}, nil, env);

	env[\bus] = CellTemplate({
		//Key could also be an array
		~overriddenMethod = 23;
		~load = \server -> {
			"Load bus".postln;
		};
	}, \server, env);

	env[\group] = CellTemplate({
		//Key could also be an array
		~anotherOverride = 0;
		~load = [\server, \bus] -> {
			"Load group";
		};
	}, [\server, \bus], env);


	template = CellTemplate({
		//Key could also be an array
		~anotherOverride = 23;
		~load = [\bus, \group] -> {
			"Load syn".postln;
		};
	}, [\bus, \group], env);


	test.assert(template.prMightHaveDeps({}), "Functions might have dependencies");
	test.assert(template.prMightHaveDeps(\foo -> {}), "Associations might have dependencies");


	test.assert(template.notNil, "Init object");
	test.assert(template.findDepsFor(\load) == [\server, \bus, \group], "Dependency order");
	test.assert(template.getMethodFunc(\load).isFunction, "getMethodFunc return value");
	test.assert(template.value[\load].isKindOf(CellFunctionList), "value return value");
	test.assert(template.value[\serverVariable] == 23, "Variables are passed from deps");
	test.assert(template.value[\overriddenMethod] == 23, "Variables can be overridden by deps later in chain");
	test.assert(template.value[\anotherOverride] == 23, "Variables can be overridden by top level template");

	template = CellTemplate({
		//Key could also be an array
		~anotherOverride = 23;
		~load = {
			"Load syn".postln;
		};
	}, [\bus, \group], env);

	test.assert(template.findDepsFor(\load).size == 3, "Fallback to global dependencies");
	test.assert(template.value[\load].isKindOf(CellFunctionList), "Global deps builds a function");


	template = CellTemplate({
		//Key could also be an array
		~anotherOverride = 23;
		~testFunction = {
			true
		};

		~testAssociation = \server -> {
			true
		};

		~load = nil -> {
			"Load syn".postln;
		};
	}, [\bus, \group], env);

	test.assert(template.findDepsFor(\load).size == 0, "Nil as key disables dependencies");
	test.assert(template.value[\load].postln.isFunction, "Nil as key builds a function");

	test.assert(template.value[\testAssociation].isFunction, "Association builds function");
	test.assert(template.value[\testAssociation].value, "Association function returns ok");
	test.assert(template.value[\testFunction].isFunction, "No deps build function");
	test.assert(template.value[\testFunction].value, "No deps function returns ok");


	test.assert(template.value[\serverSpecificMethod].isFunction, "Functions are only defined once per player") // Server defines parentGroup, and other players having server as dep is not making the server setup code run twice

};

