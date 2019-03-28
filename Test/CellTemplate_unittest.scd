if (thisThread.isKindOf(Routine).not) {
	UnitTestScript("CellTemplate", thisProcess.nowExecutingPath).runScript;
};
{
	|test|

	var template;
	var env = ();

	env[\server] = CellTemplate({
		~serverVariable = 23;
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




	test.assert(template.notNil, "Init object");
	test.assert(template.findDepsFor(\load) == #[server, bus, group], "Dependency order");
	test.assert(template.getMethodFunc(\load).isFunction, "getMethodFunc return value");
	test.assert(template.value[\load].isKindOf(FunctionList), "value return value");
	test.assert(template.value[\serverVariable] == 23, "Variables is passed from deps");
	test.assert(template.value[\overriddenMethod] == 23, "Variables can be overridden by deps later in chain");
	test.assert(template.value[\anotherOverride] == 23, "Variables can be overridden by top level template");
};