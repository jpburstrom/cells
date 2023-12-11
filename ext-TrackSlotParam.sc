+ TrackSlotParam {
	makeCV { |class, connect=true, argSpec=nil|
		var cv;
		class = class ? NumericControlValue;
		argSpec = argSpec ? spec;

		cv = class.new(value, spec);

		//If connect, make sure to call inside Connection.make
		if (connect) {
			cv.signal.connectTo(this.valueSlot);
			this.signal.connectTo(cv.valueSlot);
		};
		^cv
	}
}