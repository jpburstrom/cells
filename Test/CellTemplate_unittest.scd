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
		~serverDict = (foo: ());
		~overriddenMethod = { "hello".postln };
		~load = {
			"Load server".postln
		}
	}, nil, env);

	env[\bus] = CellTemplate({
		~overriddenMethod = 23;
		~build = {
			~serverDict[\foo] = 11;
		};
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

	template = CellTemplate({
		//Key could also be an array
		~anotherOverride = 23;
		~load = {
			"Load syn".postln;
		};
	}, [\bus, \group], env);

	test.assert(template.findDepsFor(\load).size == 3, "Fallback to global dependencies");
	test.assert(template.value[\load].isKindOf(CellFunctionList), "Global deps builds a function");

	test.assert(template.value[\load].array.asSet.size == template.value[\load].array.size, "FunctionLists have unique functions");


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

	// Other players having server as dep is not making the server setup code run twice
	test.assert(template.value[\serverSpecificMethod].isFunction, "Functions are only defined once per player");
	test.assert(template.value[\serverDict][\foo] == 11, "Build function");


	template = CellTemplate((
		build: {
			~foo = 23;
			~overriddenMethod = true;
			~serverDict[\foo][\foo] = 22;
		},
		load: {}
	), \server, env);

	test.assert(template.value[\foo] == 23, "Pass envir to constructor");
	test.assert(template.value[\overriddenMethod] == true, "Build function overrides dep methods");
	test.assert(template.value[\load].isKindOf(CellFunctionList), "Envir defined methods still makes lists if needed");
	test.assert(env[\server].value[\serverDict] !== template.value[\serverDict], "Dictionaries are copied from dependencies");
	test.assert(env[\server].value[\serverDict][\foo] === template.value[\serverDict][\foo], "Dictionaries are not deep copied from dependencies");
	test.assert(env[\server].value[\serverSpecificMethod] === template.value[\serverSpecificMethod], "Non-overridden functions are identical in deps");
	test.assert(env[\server].value[\load] === template.value[\load].array[0], "Listed functions are identical in deps");

	env[\busSomething] = CellTemplate({
	}, \bus, env);
	template = CellTemplate({
		~load = {
			"thing".postln
		};
	}, \busSomething, env);

	test.assert(template.value[\load].isKindOf(CellFunctionList),
		"Method dependencies are still picked up from subdependencies");



};
