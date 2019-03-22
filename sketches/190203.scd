//Responding to triggers (play, stop, ...)
//Playing child objects (synths, patterns)
//Handling resources (buffers, buses)
//Fading, setting volume,
//Controlling synths/patterns with (macro) parameters
//Having internal tempo, possibly synced to others
//Playing on quant
//Grouping, routing
//Rendering (freezing)

var partials = (

	serverCue: (
		server: nil,
		group: { ~server.defaultGroup.nodeID },
		out: 0
	),

);


//Cue parameters
var params =  (
	(
		//Descriptive? name
		name: "My first cue",
		id: "my-first-cue",

		//Which server to play on
		server: Server.default,
		//Parent group
		parentGroup: nil,
		//Output bus
		out: 0,

		//Fades
		fadeIn: [10, -4],
		fadeOut: [1, 4],
		volume: -3, //db

		//Quant/Clock
		tempo: 1,
		quant: nil,
	)
);