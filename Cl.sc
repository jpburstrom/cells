/*
[general]
title = "Cl"
summary = "A named Cell"
categories = "Server > Abstractions"
related = "Classes/Cell"
description = '''
'''
*/
Cl {
	classvar <all;
	var <key, <cell, rebuilding=false;

	*initClass { all = IdentityDictionary() }

	/*
	[classmethod.new]
	description="Create or return a Cl instance."
	[classmethod.new.args]
	key = "A unique key correspondning to the instance in the class-wide dictionary. Will return instance if it already exists."
	templateKey = "Key of the template to use for cell settings."
	pairs = "Instance-specific settings."
	*/
	*new { |key, templateKey ... pairs|
		var res;
		key ?? {
			Error("Missing key").throw;
		};
		res = all.at(key);
		if(res.isNil) {
			res = super.new.cell_(Cell(templateKey, *pairs)).addToAll(key);
		} {
			if (templateKey.notNil || pairs.notEmpty ) {
				//Will free old cell
				res.cell = Cell.new(templateKey, *pairs);
			};
		};
		^res
	}

	*doesNotUnderstand { |selector ... args|
		if (Cell.templates[selector].notNil) {
			^this.new(args[0], selector, *args[1..])
		} {
			^this.superPerformList(\doesNotUnderstand, selector, args);
		}
	}

	addToAll {|argkey|
		key = argkey;
		all.put(key, this)
	}

	free {
		all[key] = nil;
		cell.free;
	}

	storeOn { | stream |
		this.printOn(stream);
	}

	printOn { | stream |
		stream << this.class.name << "(" <<< key << ")"
	}	name {  cell.name() }

	cell_ { |c|
		var pos;
		if (cell.isPlaying) {
			pos = cell.clock.beats / cell.clock.tempo;
			rebuilding = true;
		};
		cell.free;
		cell = c;
		cell.addDependant(this);
		cell.name_(key);
		cell.snapshotPath = [\Cl, key];
		if (pos.notNil) {
			cell.play(pos).then { rebuilding = false };
		}
	}

	asStream {
		^Routine({ |inval|
			var val = cell.envir;
			loop {
				if (rebuilding.not) {
					val = cell.envir;
				};
				inval = val.yield
			}
		}.inEnvir)
	}

	update { |obj, what ... args|
		this.changed(obj, what, *args)
	}

	snapshotPath {
		^cell.snapshotPath;
	}

	name_ { |name| cell.name_(name) }
	argPairs {  ^cell.argPairs }
	cond {  ^cell.cond }
	clock {  ^cell.clock }
	syncClock {  ^cell.syncClock }
	syncClock_ { |clock| cell.syncClock_(clock) }
	syncQuant {  ^cell.syncQuant }
	syncQuant_ { |quant| cell.syncQuant_(quant) }
	help {  cell.help }
	load { |ffwd, argQuant, argClock| cell.load(ffwd, argQuant, argClock) }
	play { |ffwd, argQuant, argClock| cell.play(ffwd, argQuant, argClock) }
	spawn { |ffwd, argQuant, argClock| ^cell.spawn(ffwd, argQuant, argClock) }
	stop { |now = false| cell.stop(now) }
	pause {  cell.pause }
	resume {  cell.resume }
	then { |func| cell.then(func) }
	wait {  cell.wait }
	state {  ^cell.state }
	isStopped {  ^cell.isStopped }
	isLoading {  ^cell.isLoading }
	isReady {  ^cell.isReady }
	isPlaying {  ^cell.isPlaying }
	isPaused {  ^cell.isPaused }
	copy {  ^cell.copy }
	clone { |templateKey ... pairs| ^cell.clone(templateKey, *pairs) }
	doFunctionPerform { |selector, args| cell.doFunctionPerform(selector, args) }
	//Fallback
	doesNotUnderstand { |selector ... args|
		^cell.performList(selector, args);
	}

}