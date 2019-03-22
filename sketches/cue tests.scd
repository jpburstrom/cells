(
//Creating the cue
c = Cue({
	~play = {
		"Ok, i'm playing".postln;
	};

	~stop = {
		"This is the stop function".postln;
	};
});
);

//Playing
c.play;

//Stopping
c.stop;

//Adding a hook
c[\beforePlay] = {
	"This goes before play".postln;
};

//Adding a load hook, with wait time
c[\load] = {
	1.wait; //or s.sync or similar
	"Ok, continuing...".postln;
};

//this won't work, done will print before play is done
(
c.play;
"done".postln;
)

c.stop;

//But this will work -- .stop is setting a flag to stop the player right after load is finished
c.play; c.stop;

//All actions are forked if needed
//use .then to wait for action to finish
c.play.then { "done".postln; };

//This works as well
fork {
	c.play;
	"done".postln;
};


c.playerCond


//Init with environment
e = (play: { "---ok---".postln });
c = Cue(nil, e)
c.play.then { c.stop }
e[\play] = { "---okok---".postln }
c.play.then { c.stop }

//But i'm not sure why this is needed


