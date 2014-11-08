(function(global) {
    var hybrid = global.hybrid,
        View = global.View,
        Selection;

    Selection = function(initial_list) {
        this.list = [];
        this.selected_level = null;
        this.onchange_callback = null;

        var idx;
        for (idx in initial_list) {
            if (initial_list.hasOwnProperty(idx)) {
                this.add(initial_list[idx]);
            }
        }
    };

    Selection.prototype.add = function(id) {
        var node = document.getElementById(id),
            that = this,
            pos = this.list.length;

        hybrid.onTap(node, function() {
            that.select(pos, true);
        });

        this.list.push(node);
    };

    Selection.prototype.select = function(level, from_interaction) {
        if (this.selected_level !== level)  {
            hybrid.removeClass(this.list[level], 'tapped');
            hybrid.addClass(this.list[level], 'selected');
            if (this.selected_level !== null) {
                hybrid.removeClass(this.list[this.selected_level], 'selected');
            }

            this.selected_level = level;

            if (this.onchange_callback !== null &&
                from_interaction === true) {
                this.onchange_callback();
            }
        }
    };

    Selection.prototype.onChange = function(f) {
        this.onchange_callback = f;
    };

    Selection.prototype.setTitleAt = function(index, title) {
        try {
            this.list[index].title = title;
        } catch(e) {
            @log(e)
        }
    };

    global.SettingView = function() {
        this.container = document.getElementById('setting_dialog');

        var _selections = {
                video_quality: new Selection(['quality_low_button', 'quality_middle_button', 'quality_high_button']), 
                sound_buffering: new Selection(['buffering_small_button', 'buffering_middle_button', 'buffering_big_button']), 
                contrast_adjustment: new Selection(['contrast_adjustment_off_button', 'contrast_adjustment_on_button'])
            },
            _onchange_callback = null,
            label;

        function _registerOnChange(selection) {
            selection.onChange(function() {
                if (_onchange_callback !== null) {
                    _onchange_callback(_selections.video_quality.selected_level,
                                       _selections.sound_buffering.selected_level,
                                       _selections.contrast_adjustment.selected_level);
                }
            });
        }

        this.onChange = function(f) {
            _onchange_callback = f;
        };

        this.setValues = function(video_quality_level,  sound_buffering_level, contrast_adjustment_level) {
            _selections.video_quality.select(video_quality_level, false);
            _selections.sound_buffering.select(sound_buffering_level, false);
            _selections.contrast_adjustment.select(contrast_adjustment_level, false);
        };

        for (label in _selections) {
            if (_selections.hasOwnProperty(label)) {
                _registerOnChange(_selections[label]);
            }
        }

        this.setScreenSize = function(screen_width, screen_height) {
            function titleText(divisor) {
                return  String(Math.floor(screen_width / divisor)) + 'x' + String(Math.floor(screen_height / divisor));
            }
            _selections.video_quality.setTitleAt(0,titleText(4));
            _selections.video_quality.setTitleAt(1,titleText(2));
            _selections.video_quality.setTitleAt(2,titleText(1));
        };
    };

    global.SettingView.prototype = new View();
}(this));
