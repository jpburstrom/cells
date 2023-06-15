(
t = Track({~main.def = \default -> (freq: ControlSpec(220, 440, \exp, default: 440)); ~send.out = 0 -> (slotType: \trimSend)});
t[\send].out.source.hash
// t[\main].def.def.func.instVarHash
)

~this = (track: Track({ ~send.out = 0  -> (slotType: \trimSend)}), alias: ());
(
var alias = { |key ...args|
	if (args[0].isFunction) {
		~this.alias[key] = args[0];
		~this.alias[key.asSetter] = args[1];
	} {
		~this.alias[key] = {
			~this.track.at(*args[0..1]) !? { |slot| slot.get(args[2]) }
		};
		~this.alias[key.asSetter] = { |self, val|
			~this.track.at(*args[0..1]) !? { |slot| slot.set(args[2], val) }
		}
	}
};

alias.(\level, \send, \out, \level);
alias.(\trim, \send, \out, \trim);
)
{ \test.kr(spec: \unipolar) }.asSynthDef.specs


~this.alias.trim

Track().get(\level)
= 0.5

.level
TrackSlotDef

= 0.2


~this.track[\post, \out]