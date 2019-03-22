var markers = (
	onsets: #[1,2,3,4],
	singleShot: 2.5,
	phrases: [0, 3]
);

var routs = ();
markers.keysValuesDo { |k, v|
	var diff;
	markers[k] = markers[k].asArray;
	diff = markers[k].differentiate;
	routs[k] = fork {
		diff.do { |time, i|
			time.wait;
			[\marker, k, diff[i+1]].postln;
		}
	}
}
			