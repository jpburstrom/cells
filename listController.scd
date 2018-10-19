var proto = Require("playController") <> {
	var synth, buf, routs;

	~score = [
		 Fdef(\createPlayer).({
			~name = "test";
			//~prewait = 2;

			~play = { |parent|
				"playing!!!".postln;
				{ 3.wait; parent.stop; "topped".postln }.fork
			};
		})

	];

	~addFork = { |func|
		routs = routs.add(func.fork);
	};

	~connections = ConnectionList();
	//TODO: Add/remove children on play/stop, signal when it happens
	~children = List();


	~loaderQueue = List();
	~loaderCond = Condition().test_({ ~loaderQueue.isEmpty.not });
	~loader = Routine({
		loop {
			while {~loaderQueue.isEmpty.not} {
				~loaderQueue.pop.load;
			};
			~loaderCond.wait;
		};
	});

	~loadNext = { |list, i=(-1)|
		list[i + 1] !? { |obj|
			if (obj.isArray) {
				~loadNext.(obj);
			} {
				~loaderQueue.add(obj);
				~children.add(obj);
				/*
				~connections.add(
					obj.signal(\stopped).connectTo(~children.methodSlot("remove(object.postln)")));
				*/
				~loaderCond.signal;
			}
		};
	};

	~traverseScore = { |list|
		list.do { |obj, i|
			if (obj.isArray) {
				~addFork.value({
					~traverseScore.(obj);
				})
			} {
				obj.get(\prewait) !? _.wait;
				//Wait for a trigger, in this case a button press
				//Players (optionally) have wait points (start, stop, part II etc) (maybe implement later)
				//Players also have triggers (onStart, onStop, onPartII etc)

				//TODO: fix interface
				//TODO: Stop trigger
				//TODO: custom triggers (markers) in players
				//TODO: custom trigger points in players
				obj.get(\playTrigger) !? { |func|
					var cond = Condition();
					fork {
						func.value({ cond.unhang })
					};
					cond.hang;
				};
				~loadNext.value(list, i);
				obj.play;
				//LATER: object signals wait point, cuelist sets up a wait condition
				//Or is object itself responsible for waits and conditions?
				obj.get(\waitPoints) !? { |trg|
					trg.do {
					}
				};
				if (true == obj.get(\waitForStop)) {
					var cond = Condition();
					obj.onStop.addFunc({cond.unhang});
					cond.hang;
				};
				obj.get(\postwait) !? _.wait;
			};
			//This makes score items come in correct order
			0.wait;
		};
	};

	~rout = Routine({
		~traverseScore.(~score);
	});

	~load = { |player|
		~loader.play;
		~loadNext.(~score);
	};

	~play = { |player|
		~rout.play
	};

	//Stop action. if you want to
	~beforeStop = { |player|
		~loader.stop;
		routs.stop;
		//~children.copy.postln.do { |xh| xh.stop }; //This should be automatic, no?
		//~connections.free;
	};

	~stop = {
		~rout.stop;

	};

	~freeAll = {
		~score.deepDo(99, (_.freeAll))
	};


};


Fdef(\makeCueList, { |obj, func|
	if (obj.isArray) {
		proto <> ({ ~score = obj } <> func);
	};
	proto <> func;
});

z = (proto <> ({ ~score = [Fdef(\makeCue).value { ~play = { "playing".postln }; ~stop = {"stop".postln }}] }));
z.play


