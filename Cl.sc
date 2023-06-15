/*
[general]
title = "Cl"
summary = "A named Cell"
categories = "Server > Abstractions"
related = "Classes/Cell"
description = '''
'''
*/
Cl : Cell {
	classvar <all;
	var <key;

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
		if(res.isNil or: {  templateKey.notNil || pairs.notEmpty }) {
			var pos;
			if (res.isPlaying) {
				pos = res.clock.beats / res.clock.tempo;
			};
			res.free;
			res = super.new(templateKey, *pairs).addToAll(key);
			res.name_(key);
			if (pos.notNil) {
				res.play(pos);
			}
		};
		^res
	}

	*doesNotUnderstand { |selector ... args|
		if (templates[selector].notNil) {
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
		super.free;
	}

	copy {
		^super.copy
	}

	storeOn { | stream |
		this.printOn(stream);
	}

	printOn { | stream |
		stream << this.class.name << "(" <<< key << ")"
	}

}