CellTimeLabel : SCViewHolder {
    var <task, waitTime;

    *new { |w, b|
        ^super.new.init(w, b);
    }

    init { |w, b|
        waitTime = 0;
        view = StaticText(w, b);
        view.string = this.secondsToString(0);
        task = Task({
            var i = -1;
            loop {
                waitTime = AppClock.seconds;
                i = i + 1;
                this.value_(i);
                1.wait;
            }
        }, AppClock);
    }



    pause {
        if (task.isPlaying) {
            waitTime = AppClock.seconds - waitTime;
            task.pause;
        }
    }

    play {
        fork {
            waitTime.wait;
            task.play;
        }
    }

    stop {
        task.stop;
        task.reset;
        waitTime = 0;
        view.string = this.secondsToString(0);

    }

    value_ { arg s;
        view.string = this.secondsToString(s);
    }

    secondsToString { arg s;
        var decimal, minutes, seconds;
        if (s == inf) {
            ^"∞";
        };
        if (s == nil) {
            ^"--:--:--";
        };
		decimal = s.asInteger;
		minutes = (decimal.div(60) % 60).asString.padLeft(2, "0").add($:);
		seconds = (decimal % 60).asString.padLeft(2, "0");
		^minutes ++ seconds ++ ":00"
	}
}
