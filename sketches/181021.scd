//Default behaviour is put in envir.parent.

//or IdentityDictionary
~cueTypes = Environment.make {

	~oneShot = Environment.make {
		~duration = 0;
		~prewait = 0;
		~play = {};
		~params = (

		)
	};

	~server = ();

};

Cue.midiCC({

	~cc = 127;
	~value = 64;

	~play = { |self|
		//override play action,
	};

});

(play: {currentEnvironment.play}).play.parent
/*
Types:
- Oneshot (action without duration)
	- Print
	- OSC
    - Midi
		- note
		- cc
		..
	- Function (arbitrary)

//Kolla på hur Event gör det med partial types (partialEvents.putAll)
//Eventuellt kan man formulera det som functions istället.

//I Proto samlas defaults för aktuell cue

//Parent: generellt beteende, funktioner och constants. Ska dessa inte gå att skriva över, tex
//OneShot duration = 0, maxdur = 0? Eller är det här specs ska definieras?
//Här kommer också saker som gui och andra meta-inställningar

//Proto: Parameters med initial values. Dessa är per instans. Exempel här är volym, pan
//Envir: Params från proto plockas in som NumericControlValue el motsv, och sätts till default. Sedan är det upp till



c = Cue.make {
	~play = { 4.wait; "ok, playing".postln }
}.play

c.envir


z = Proto { ~testing = { "hello".postln } }
z.make { ~testing = { "no".postln } }
z[\testing] = nil
z.testing


IdentityDictionar

//Soundfile
CueDef("/path/to/file.wav")

//Default value