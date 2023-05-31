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
			res.free;
			res = super.new(templateKey, *pairs).addToAll(key);
			res.name_(key);
		};
		^res
	}

	addToAll {|argkey|
		key = argkey;
		all.put(key, this)
	}

	free {
		all[key] = nil;
		super.free;
	}

	storeOn { | stream |
		this.printOn(stream);
	}

	printOn { | stream |
		stream << this.class.name << "(" <<< key << ")"
	}

}