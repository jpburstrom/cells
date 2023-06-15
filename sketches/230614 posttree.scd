(
c = Cell(\pattern,

	// \template, (synth: (main: (default: \default -> (freq: 220)))),
	Pbind(),
	\settings, ( fadeOut: 3)
	/*
	\load, {
		~trackAuto.fadeIn(1, 3)
	}
	*/

).play
)


c.stop
c.track.postTree

Cell.loadTemplates

(
var tabs = 0;
var postTree = { |obj, str|
	obj.keysValuesDo { |k, v|
		if (v.isKindOf(Dictionary)) {
			tabs.do { str << "\t" };
			str << "%:\n".format(k);
			tabs = tabs + 1;
			postTree.(v, str);
			tabs = tabs - 1;
		} {
			tabs.do { str << "\t" };
			str << "%: %".format(k, v.asString);
			str << "\n"
		}
	}
};
postTree.(Cell(\buffer, "/Users/johannes/lovestory.wav").template, Post)

)
Library.postTree

Cell(\buffer).template.keysValuesDo( { |k, v| k.postln; v.keysValues



Cell(\pattern).envir[\templateStop].cs


c
C


Cell.debug = true
c.load.then( { c.state.postln })


c.stop
c.trackAuto
c.play.then { currentEnvironment.postln; c.track.postln }