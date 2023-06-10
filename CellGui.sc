//TODO: Get current state from CellList when creating the window
CellGuiBase : SCViewHolder {

    classvar keyCodes;

    var <model,
    fixedHeight = 35,
    bgAlpha = 0.5,
    bg = "000",
    selectBg = "0A2",
    color = "FFF";

    *initClass {
        keyCodes = IdentityDictionary[
            \escape -> 16r01000000,
            \tab -> 16r01000001,
            \backtab -> 16r01000002,
            \backspace -> 16r01000003,
            \return -> 16r01000004,
            \enter -> 16r01000005,
            \insert -> 16r01000006,
            \delete -> 16r01000007,
            \home -> 16r01000010,
            \end -> 16r01000011,
            \left -> 16r01000012,
            \up -> 16r01000013,
            \right -> 16r01000014,
            \down -> 16r01000015,
            \pageUp -> 16r01000016,
            \pageDown -> 16r01000017,
            \f1 -> 16r01000030,
            \f2 -> 16r01000031,
            \f3 -> 16r01000032,
            \f4 -> 16r01000033,
            \f5 -> 16r01000034,
            \f6 -> 16r01000035,
            \f7 -> 16r01000036,
            \f8 -> 16r01000037,
            \f9 -> 16r01000038,
            \f10 -> 16r01000039,
            \f11 -> 16r0100003a,
            \f12 -> 16r0100003b
        ]
    }

    view_ { arg v;
		// subclasses need to ALWAYS use this method to set the view
		view = v;
        model.addDependant(this);
        //Attach this to child;
        this.view.onClose = {
            this.viewDidClose;
            model.removeDependant(this);
        };
    }

    prLabel { arg st, minWidth;
        ^StaticText()
        .align_(\left)
        .stringColor_(Color.fromHexString(color))
        .background_(Color.fromHexString(bg).alpha_(0.5))
        .fixedHeight_(fixedHeight)
        .maxWidth_(100)
        .string_(st)
        .minWidth_(minWidth)
    }
    prTimeLabel { arg v;
        var timeLabel = CellTimeLabel().value_(v);
        timeLabel.view.align_(\center)
        .background_(Color.fromHexString(bg).alpha_(bgAlpha))
        .stringColor_(Color.fromHexString(color))
        .fixedHeight_(fixedHeight);
        ^timeLabel
    }

    setActive { |active = true|
        var b = bg;
        if (active) { b = selectBg } ;
        this.background_(Color.fromHexString(b));
    }

    remove {

        ^super.remove;
    }

}

CellGui : CellGuiBase {
    classvar stateLabels;
    var num, <things, timeLabel, stateLabel;

    *initClass {
        stateLabels = IdentityDictionary[
            \stateless -> "•",
            \stopped -> "◼",
            \loading -> "✇",
            \ready -> "√",
            \playing -> "▶",
            \paused -> "▷",
            \error -> "?",
            \stopping -> "◻"
        ]
    }

    *new { |num, model, parent, bounds|
        ^super.new.init(model, num, parent, bounds);
    }
    init { |amodel, anum, parent, bounds|
        model = amodel; num = anum;
        bounds = bounds ?? { Rect(0,0,600,35) };
        this.view = View(nil, bounds);

        things = IdentityDictionary[
            \number -> this.prLabel(num, 35),
            \state -> this.prLabel(stateLabels[model.state], 35),
            \name -> this.prLabel(model.name).maxWidth_(9999),
            \time -> timeLabel = this.prTimeLabel(nil),
            \preWait -> this.prTimeLabel(model.preWait),
            \dur -> this.prTimeLabel(model.duration)
        ];

        view.layout = HLayout().spacing_(0).margins_(2, 0, 2, 0);
        view.layout.add(things[\number], 0);
        view.layout.add(things[\state], 0);
        view.layout.add(things[\name], 4);
        view.layout.add(things[\time].view, 1);
        view.layout.add(things[\preWait].view, 1);
        view.layout.add(things[\dur].view, 1);

        this.setActive(false); //init color

    }


    update { arg cue, what, args;
        var z = cue.state, n = cue.name;

        defer {
            if (what == \state) {
                things[\state].string_( stateLabels[z]);

                switch (z,
                    \stopped, { things[\time].stop },
                    \playing, { things[\time].play },
                    \paused, { things[\time].pause }
                );
                this.reset;

            };

            if (what == \name) {
                things[\name].string = n;
            }
        }
    }

    reset {
        things[\preWait].value_(model.preWait);
        things[\dur].value_(model.duration);
    }


}

CellListGui : CellGuiBase {
    var <canvas, current, <items, <>keyActions, <scroll;

    *new { |model, parent, bounds|
        ^super.new.init(model, parent, bounds);
    }

    populate {
        canvas.layout = VLayout().margins_(0).spacing_(1);
        model.do { |item, i|
            var g = CellGui(i + 1, item);
            g.mouseDownAction = { arg ... args;
                model.setIndex(i);
            };
            items.add(g);
            canvas.layout.add(g.view);
            g.setActive(model.current == i);
        };
        canvas.layout.add( nil );
    }

    init { | amodel, parent, bounds |
        var header;
        model = amodel;
        current = model.current.max(0);
        items = List();

        bounds = bounds ?? { Rect(0, 0, 800, 600) };
        this.view = View(parent, bounds);
        this.view.keyDownAction_({});
        view.layout = VLayout().margins_(1).spacing_(1);
        view.layout.add( this.makeHeader() );
        scroll = ScrollView(parent, bounds)
        .hasHorizontalScroller_(false).hasVerticalScroller_(false);
        view.layout.add(scroll);

        //Scroll
        canvas = View().maxWidth_(1200);
        this.populate;
        scroll.canvas = canvas;
        this.setScroll;
        scroll.keyDownAction_({});

        keyActions = IdentityDictionary[
            $V -> { model.play; false },
            $S -> { model.stop; false },
            $D -> { model.stop(true); false },
            $P -> { model.pause; false },
            $L -> { model.load; false },
            //Down
            $J -> { model.next; false },
            //UP
            $K -> { model.prev; false },
            //Enter
            keyCodes[\return] -> {

            };
            //Esc
            keyCodes[\escape] -> {
                model.reset;
                false
            }
        ];

        this.keyDownAction = { arg v, c, mod, unicode, kcode, k;
            if (k < 128) { k = k.asAscii };
            //Pass key to cue itself,
            //Using a ~keyActions dictionary in its environment
            keyActions[k].value ?? true;
        };

        View.globalKeyDownAction = { arg v, c, mod, unicode, kcode, k;
            var current;
            var actions = IdentityDictionary[
                Char.space -> { model.go; false },

            ];
            if (k < 128) { k = k.asAscii };
            if (actions[k].value != false) {
                current = model[model.current];
                if (current.notNil) {
                    current[\keyActions] !? { current[\keyActions][k].value};
                }

            };
            false;
        };

        //Front if needed
        if(parent.isNil, {
            this.front;
        });

    }

    makeHeader {
        var parent  = View(nil, Rect(0, 0, 600, 35)).background_(Color.gray);
        parent.layout = HLayout().spacing_(0).margins_(0);
        fixedHeight = 20;
        bg = "#444";
        parent.layout.add(this.prLabel("#", 35), 0);
        parent.layout.add(this.prLabel("!", 35), 0);
        parent.layout.add(this.prLabel("Name").maxWidth_(9999), 4);
        parent.layout.add(this.prLabel("Time").maxWidth_(9999), 1);
        parent.layout.add(this.prLabel("Pre"), 1);
        parent.layout.add(this.prLabel("Dur"), 1);
        ^parent

    }

    update { arg what, signal, i;
        if (signal == \current) {
            current !?  { items[current].setActive(false) };
            current = i;
            current !? { items[current].setActive(true) };
            this.setScroll
        } {
            if (signal == \items) {
                canvas.removeAll;
                items.clear;
                this.populate;
                this.setScroll;
            }
        }
    }

    setScroll {
        if (items.notEmpty) {
            scroll.visibleOrigin = Point(0, items[current].bounds.top - (scroll.bounds.height / 2)) //SPACING
        }
    }

}