if (thisThread.isKindOf(Routine).not) {
	UnitTestScript("CellTemplate", thisProcess.nowExecutingPath).runScript;
};
{
	|test|

	var template;
	var env = ();

	env[\server] = CellTemplate({
		~load = {
			"Load server".postln
		}
	}, env);

	env[\bus] = CellTemplate({
		//Key could also be an array
		~load = \server -> {
			"Load bus".postln;
		};
	}, env);

	"ok then".postln;

	env[\group] = CellTemplate({
		//Key could also be an array
		~load = [\server, \bus] -> {
			"Load group".postln;
		};
	}, env);

	"ok then 2".postln;

	template = CellTemplate({
		//Key could also be an array
		~load = [\bus, \group] -> {
			"Load syn".postln;
		};
	}, env);




	test.assert(template.notNil, "Init object");
	test.assert(template.findDepsFor(\load) == #[server, bus, group], "Dependency order");
	test.assert(template.getMethodFunc(\load).isFunction, "getMethodFunc return value");
	test.assert(template.value[\load].isKindOf(FunctionList), "value return value");

};