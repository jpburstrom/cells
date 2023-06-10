CellList : List {
    var <current;

    *new { |size|
        ^super.new(size).init;
    }


    init {
        current = -1;
    }

    put { arg i, item;
        if (this.prprCheckItem(item)) {
            array.put(i, item)
        }
    }
	clipPut { arg i, item; i = i.asInteger.clip(0, this.size - 1); this.put(i, item);}
	wrapPut { arg i, item; i = i.asInteger.wrap(0, this.size - 1); this.put(i, item);  }
	foldPut { arg i, item; i = i.asInteger.fold(0, this.size - 1); this.put(i, item) }

	add { arg item;
        var test;
        #test, item = this.prCheckItem(item);
        if (test) {
            array = array.add(item);
            this.changed(\items)
        }
    }
	addFirst { arg item;
        var test;
        #test, item = this.prCheckItem(item);
        if (test) {
            array = array.addFirst(item);
            this.changed(\items)
        }
    }
    insert { arg index, item;
        var test;
        #test, item = this.prCheckItem(item);
        if (test) {
            array = array.insert(index, item);
            this.changed(\items)
        }
    }
	removeAt { arg index;
        array.removeAt(index);
        this.changed(\items);
    }
	clear { super.clear; this.changed(\items) }
	pop { array.pop; this.changed(\items) }
	first { if (this.size > 0, { ^array.at(0) }, { ^nil }) }
	last { if (this.size > 0, { ^array.at(this.size - 1) }, { ^nil }) }
	fill { arg item; array.fill(item); this.changed(\items) }

    go {
        this.play;
        this.next;
        this.load;
    }

    play { this.performOnCue(\play) }

    load { this.performOnCue(\load) }

    stop { |now| this.performOnCue(\stop, now) }

    pause { this.performOnCue(\pause) }

    stopAll { |now| this.do(_.stop(now)) }

    performOnCue { |what, ark|
        if (this.size > 0) {
            current !? {
                this.at(current) !? {
                    this.at(current).perform(what, ark);
                }
            }
        }
    }

    next {
        ^this.prPrevNext(1)
    }

    prev {
        ^this.prPrevNext(-1)
    }

    setIndex { |index|
        current = index.wrap(0, this.size - 1);
        this.changed(\current, current);
        ^this.at(current);
    }
    setFirst { this.setIndex(0) }

    setLast { this.setIndex(this.size - 1) }

    reset {
        this.stopAll(true);
        this.setIndex(0);
        this.load;
    }

    prPrevNext { |dir|
        if (current.isNil) {
            if (this.size > 0) {
                ^this.setIndex(0);
            } {
                ^nil;
            }
        };
        ^this.setIndex(current + dir);

    }

    prCheckItem { |item|
        var test;
        if (item.isKindOf(Symbol)) {
            item = Cl.all[item]; //Can be nil
        } {
            if (item.isKindOf(Association)) {
                item = OneShotOtherCue.actions[item.key].perform(\new, item.value);
            } {
                if (item.isKindOf(Collection)) {
                    item = GroupCue(item.join("|"), {
                        ~cues = item.select({ arg x; this.prCheckItem(x)[0]})
                        .collect({ arg x; this.prCheckItem(x)[1]})
                        ;
                    })
                }
            }
        };
        test = item.isKindOf(Cell);
        if (test == false) {
            "CueList needs Cells (not %)".format(item.asString).warn;
        };
        ^[test, item]
    }

    gui {
        ^CellListGui(this);
    }

    document { |name|
        var str;
        str = this.asCompileString;
        ^str.newTextWindow((name ? this.class.name).asString)
    }

    //Adding newlines to compilestring
    storeOn { | stream |
        if (stream.atLimit) { ^this };
        stream << this.class.name << "[ " ;
        this.storeItemsOn(stream);
        stream.nl;
        stream << "]" ;
    }
    storeItemsOn { | stream |
		var addComma = false;
		this.do { | item |
			if (stream.atLimit) { ^this };
			if (addComma) { stream.comma.nl.tab; } { stream.nl.tab; addComma = true };
			item.storeOn(stream);
		};
	}

}
