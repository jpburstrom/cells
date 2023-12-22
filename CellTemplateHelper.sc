CellTemplateHelper {

	var <>template, <resolvedTemplate;
	var <>keyLabel, <>valueLabel;

	*new { |template|
		^super.newCopyArgs(template).init;
	}

	init {
		keyLabel = \source;
		valueLabel = \target;
	}


	collectTemplate { |object|
		var out;
		object.pairsDo({ |source, target|
			target = this.unfoldTemplateForKey(target, valueLabel);
			if (keyLabel != false) {
				source = this.unfoldTemplateForKey(source, keyLabel);
				source.do { |src|
					target.do { |tgt|
						out = out.add(IdentityDictionary().putAll(src, tgt));
					}
				};
			} {
				target.do { |tgt|
					out = out.add(source);
					out = out.add(IdentityDictionary().putAll(tgt));
				}
			}
		});
		^out
	}

	resolveTemplate {
		^resolvedTemplate = this.collectTemplate(template);
	}

	unfoldTemplateForKey { |obj, objectKey, asArray=true|
		case { obj.isKindOf(Dictionary) } {
			//Support for (key: array_of_keys) with common settings
			var keyValue = obj.removeAt(objectKey);
			var out = this.unfoldTemplateForKey(keyValue, objectKey, true).collect { |o|
				o.putAll(obj);
			};
			^if (asArray) { out  } { out.unbubble };
		} { obj.isArray and: { obj.isString.not } } {
			^obj.collect({ |item|
				this.unfoldTemplateForKey(item, objectKey, false)
			});

		} {
			obj = IdentityDictionary[
				objectKey.asSymbol -> obj.copy
			];

			^if (asArray) { [obj] } { obj };
		};
	}

}