"Loading parentEnvironment".debug;

Environment.make {


	~nodeMap = MultiLevelIdentityDictionary();

	~addNodeMap = { |...path|
		var map = ~nodeMap.atPath(path);
		if (map.isNil) {
			map = NodeMap();
			~nodeMap.putAtPath(path, map);
		};
		map
	};

	// Get values from running synths
	~get = { |first ...rest|
		var out, path;
		if (first.isKindOf(String)) {
			first = first.split($.).collect(_.asSymbol);
		} {
			first = first.asArray;
		};
		path = first ++ rest;
		out = ~nodeMap.at(*path);
	};

	~set = { |first ...rest|
		var key, val, out, path;
		if (first.isKindOf(String)) {
			first = first.split($.).collect(_.asSymbol);
		} {
			first = first.asArray;
		};
		path = first ++ rest;
		val = path.pop;
		key = path.pop;
		out = ~nodeMap.at(*path);
		if (out.isKindOf(NodeMap)) {
			out.set(key, val);
			if (currentEnvironment.isPlaying) {
				~prNodeMapSend.(out, path);
			};
		} {
			nil
		};
		out
	};


	~prNodeMapSend = { |map, path|
		var type = path[0];
		var key = path[1];

		//Get playing node from map path
		if (type == \group) {
			map.sendToNode(~groups[key]);
		} {
			~synths[type] !? { |typeDict|
				map.sendToNode(typeDict[key]);
			}

		}

	};

	~settings = (
		//Number of out channels
		numChannels: 2,


		// --- DURATIONS ---
		// Total cell duration
		duration: inf,
		// Duration of tail
		// Time until silent after all players have stopped playing.
		// In case of synths, wait for tailDuration after all synths have stopped.
		// In case of patterns, wait for tailDuration after pattern has stopped.
		// This means you have to add pattern note release time to tailDuration
		// This is useful for delays or reverbs put in the fx group
		// TODO:
		tailDuration: 0,

		// --- SYNC ---
		// By default, TempoClock.default is used.
		// Tempo is set on quantized play start.
		// quant.timingOffset can be used to start playback earlier,
		// for example if a sample starts on an upbeat.
		tempo: 1,
		// Set timingOffset here, if needed
		quant: nil,


		// --- FADES ---
		// Fades are post-fx, and overrides tail settings.
		// This means it should be safe to free everything when a fadeOut has completed.
		// Fade in duration.
		fadeIn: 0,
		// Curve of fadeIn envelope - only float?
		fadeInCurve: 8,
		// Fade out duration. This overrides tailDuration.
		fadeOut: 0,
		// Curve
		fadeOutCurve: -8,

		// If true, release main synths in .afterStop
		releaseAfterStop: true,


		// Default arguments for new synths
		defaultSynthArgs:  IdentityDictionary[
			\out -> {~bus.main}
		]
	);


}



