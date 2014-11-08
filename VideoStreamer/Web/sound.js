(function(global) {
    var hybrid = global.hybrid,
        storage = global.storage,
        MIC_GRANTED = parseInt('$_$MIC_GRANTED$_$', 10) !== 0; // jshint ignore:line

    global.VolumeControl = function(root) {
        var _doc = {
                volume_root: hybrid.getChildOfClass(root, 'volume_control'),
                touch_area: hybrid.getChildOfClass(root, 'volume_control_slider_touch_area'),
                slider: hybrid.getChildOfClass(root, 'volume_control_slider'),
                back: hybrid.getChildOfClass(root, 'volume_control_slider_back'),
                knob: hybrid.getChildOfClass(root, 'volume_control_slider_knob'),
                effective: hybrid.getChildOfClass(root, 'volume_display_touch_area'),
                moving_parts: hybrid.getChildOfClass(root, 'volume_control_slider_box'),
                button: hybrid.getChildOfID(root, 'volume_button'),
                icon: hybrid.getChildOfID(root, 'volume_img')
            },
            _knob_ratio = _doc.knob.offsetHeight / _doc.slider.offsetHeight,
            _knob_margin = 0,
            _on_change = null,
            _on_tap = null,
            _on_drag_end = null,
            _value = 0,
            _prev_icon_state = global.__undefined,
            _icons = ["volume_mute.png",
                     "volume_0.png",
                     "volume_1.png",
                     "volume_2.png"],
            _enable_effective = false,
            _enable_slider_area = false,
            _enable_button = false,
            _enable_drag = false,
            _enabled;

        function _calcValueFromTouchY(y) {
            var touch_margin_top = hybrid.calcElementOffset(_doc.touch_area, _doc.slider).y,
                y_ratio = (y + _knob_margin - touch_margin_top) / (_doc.touch_area.offsetHeight - touch_margin_top);
            // Clamp its moving range of the knob to fit in the slider
            return (1 - hybrid.clamp(y_ratio, _knob_ratio, 1)) / (1 - _knob_ratio);
        }

        function _updateSlider(v) {
            v = hybrid.clamp(v);

            var percent_str = String((v * (1 - _knob_ratio)) * 100) + '%';

            _doc.knob.style.bottom = percent_str;
            _doc.back.style.height = percent_str;
        }

        function _updateIcon(v) {
            var icon_state;
            if (v < 0.01) {
                icon_state = 0;
            } else if (v < 0.5) {
                icon_state = 1;
            } else if (v < 1.0) {
                icon_state = 2;
            } else {
                icon_state = 3;
            }

            if (_prev_icon_state !== icon_state) {
                _prev_icon_state = icon_state;
                _doc.icon.src = _icons[icon_state];
            }
        }

        function _updateUI(v) {
            _updateSlider(v);
            _updateIcon(v);
        }

        function _grabKnob(y) {
            var knob_y = hybrid.calcElementOffset(_doc.touch_area, _doc.knob).y;

            if (y - knob_y < _doc.knob.offsetHeight && y - knob_y >= 0) {
                // When grabbing the knob, let it be still on mousedown
                _knob_margin = - (y - knob_y) + _doc.knob.offsetHeight;
            } else {
                // When moving the knob to clicked position, centering the knob at the touch point
                _knob_margin = _doc.knob.offsetHeight / 2;
            }
        }

        function _setValue(v) {
            if (!_enabled) { return; }
            _value = hybrid.clamp(v);
            _updateUI(_value);
        }

        function _checkVolumeDisplayEnabled() {
            return (_enable_drag || _enable_effective || _enable_slider_area || _enable_button);
        }

        function _checkVolumeDisplayDismiss() {
            // Delay and double check disabled condition to avoid flapping
            if (!_checkVolumeDisplayEnabled()) {
                setTimeout(function() {
                    if (!_checkVolumeDisplayEnabled()) {
                        hybrid.removeClass(_doc.moving_parts, 'visible');
                        setTimeout(function() {
                            if (!_checkVolumeDisplayEnabled()) {
                                hybrid.dismiss(_doc.volume_root);
                            }
                        },300);
                    }
                }, 800);
            }
        }

        function _unuse() {
            hybrid.unused(_doc.button);
            hybrid.addClass(_doc.button, 'pressed');
            _value = 0;
            _updateUI(0);
            _enabled = false;
            _enable_drag = false; 
            _enable_effective = false; 
            _enable_slider_area = false; 
            _enable_button = false;
            _checkVolumeDisplayDismiss();
            if (_on_change !== null) {
                _on_change(_value);
            }
        }

        function _use() {
            _enabled = true;
            hybrid.removeClass(_doc.button, 'pressed');
            hybrid.removeClass(_doc.button, 'unused');
            hybrid.removeClass(_doc.button, 'locked');
            hybrid.addClass(_doc.button, 'used');
            if (_on_change !== null) {
                _on_change(_value);
            }
        }

        this.getValue = function() {
            return _value;
        };

        this.setValue = _setValue;

        this.onChange = function(f) {
            _on_change = f;
        };

        this.onDragEnd = function(f) {
            _on_drag_end = f;
        };

        this.onTap = function(f) {
            _on_tap = f;
        };

        this.unuse = _unuse;
        this.use = _use;

        /*jslint unparam: true*/
        hybrid.onCoherentDrag(_doc.touch_area, function(_, y) {
            if (!_enabled) { return; }
            _setValue(_calcValueFromTouchY(y));
            if (_on_change !== null) {
                _on_change(_value);
            }
            _enable_drag = true;

            // these lines make the slider look consistent when app disabled and enabled audio while dragging
            hybrid.show(_doc.volume_root);
            hybrid.addClass(_doc.moving_parts, 'visible');
        }, function(_, y) {
            if (!_enabled) { return; }
            _grabKnob(y);
            _setValue(_calcValueFromTouchY(y));
            if (_on_change !== null) {
                _on_change(_value);
            }
        }, function() {
            if (!_enabled) { return; }
            _enable_drag = false;
            _checkVolumeDisplayDismiss();

            if (_on_drag_end !== null) {
                _on_drag_end(_value);
            }
        });
        /*jslint unparam: false*/

        if (MIC_GRANTED) {
            hybrid.onHover(_doc.touch_area, function() {
                if (!_enabled) { return; }
                _enable_slider_area = true;
            }, function() {
                if (!_enabled) { return; }
                _enable_slider_area = false;
                _checkVolumeDisplayDismiss();
            });

            hybrid.onHover(_doc.effective, function() {
                if (!_enabled) { return; }
                _enable_effective = true;
            }, function() {
                if (!_enabled) { return; }
                _enable_effective = false;
                _checkVolumeDisplayDismiss();
            });

            hybrid.onHover(_doc.button, function() {
                if (!_enabled) { return; }
                if (!_checkVolumeDisplayEnabled()) {
                    hybrid.show(_doc.volume_root);
                    setTimeout(function() {
                        hybrid.addClass(_doc.moving_parts, 'visible');
                    },100);
                }
                _enable_button = true;
            }, function() {
                if (!_enabled) { return; }
                _enable_button = false;
                _checkVolumeDisplayDismiss();
            });

            hybrid.onTap(_doc.button, function() {
                if (!_enabled) { return; }
                if (_on_tap !== null) {
                    _on_tap();
                }
            });

            this.setValue(_value);
        } else {
            _unuse();
        }

        hybrid.dismiss(_doc.volume_root);
    };

    global.AudioPlayer = function(volume_control) {
        var AudioContext = window.AudioContext||window.webkitAudioContext,
            _audio_ctx = null, 
            _scheduled_time = null,
            _volume_control = volume_control,
            _enabled_state = false,
            _enabled_state_listener = null,
            _delay_state_listener = null,
            _scheduled_audio_captured_sec = null, 
            _current_duration = null,
            _gain_node = null,
            _prev_volume = null,
            _first_use_control = true,
            _audio_chunk = null,
            _first_tap = true,
            // Table of index changes
            ADPCM_INDEX_TABLE = new Int32Array([
                -1, -1, -1, -1, 2, 4, 6, 8,
                -1, -1, -1, -1, 2, 4, 6, 8
            ]),
            // Quantizer step size lookup table
            ADPCM_STEP_SIZE_TABLE = new Int32Array([
                7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
                19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
                50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
                130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
                337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
                876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
                2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
                5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
                15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
            ]),
            BUFFER_RATIO = 2.0;

        function _isEnabled() {
            return _gain_node.gain.value >= 0.01;
        }

        function _checkEnabledStateChange() {
            if (_isEnabled() !== _enabled_state && _enabled_state_listener !== null) {
                _enabled_state = !_enabled_state;
                _enabled_state_listener(_enabled_state);
            }
        }

        function _notifyEnabledState() {
            if (_enabled_state_listener === null) { return; }
            _enabled_state = _isEnabled();
            _enabled_state_listener(_enabled_state);
        }

        function _getSavedVolumeValue() {
            if (hybrid.mobileCheck()) { return; }

            var ret_value = 0.5,
                saved_value = storage.get('sound_volume');

            if (saved_value !== null) {
                ret_value = Math.max(Math.min(1.0, parseFloat(saved_value)), 0);
            }

            return ret_value;
        }

        function _saveVolumeValue(value) {
            if (hybrid.mobileCheck()) { return; }

            storage.set('sound_volume', value);
        }

        function _setVolume(volume, force_notification) {
            _gain_node.gain.value = volume;

            if (force_notification === true) {
                _notifyEnabledState();
            } else {
                _checkEnabledStateChange();
            }
        }

        function _getVolume() {
            return _gain_node.gain.value;
        }

        function _getAudioTime() {
            return _audio_ctx.currentTime;
        }

        function _getAudioSyncTime() {
            if (_scheduled_audio_captured_sec === null || 
                _scheduled_time === null ||
                !_isEnabled()) {
                return -1;
            }

            return _scheduled_audio_captured_sec + 
                _audio_ctx.currentTime - _scheduled_time;
        }

        function _dummyPlay() {
            var audio_src = _audio_ctx.createBufferSource();
            audio_src.connect(_gain_node);
            if (audio_src.start === global.__undefined) {
                audio_src.noteOn(0);
            } else {
                audio_src.start(0);
            }
        }

        function _scheduleAudio(chunk_f32, captured_sec) {
            var audio_ctx = _audio_ctx,
                audio_buf = audio_ctx.createBuffer(1, chunk_f32.length, 44100),
                audio_src = audio_ctx.createBufferSource(),
                scheduled_time = _scheduled_time,
                current_time = audio_ctx.currentTime;

            audio_buf.getChannelData(0).set(chunk_f32);

            audio_src.buffer = audio_buf;
            audio_src.connect(_gain_node);

            if (scheduled_time === null) {
                scheduled_time = 0;
            }

            if (current_time < scheduled_time) {
                scheduled_time += audio_buf.duration;
            } else {
                scheduled_time = current_time + audio_buf.duration * BUFFER_RATIO;
                if (_delay_state_listener !== null) {
                    setTimeout(function() {
                        _delay_state_listener(scheduled_time - current_time);
                    }, 1);
                }
            }

            if (audio_src.start === global.__undefined) {
                audio_src.noteOn(scheduled_time);
            } else {
                audio_src.start(scheduled_time);
            }

            _scheduled_time = scheduled_time;
            _current_duration = audio_buf.duration;

            _scheduled_audio_captured_sec = captured_sec;
        }

        function _getAudioChunk(code_length) {
            if (_audio_chunk === null ||
                _audio_chunk.length !== code_length * 2) {
                _audio_chunk = new Float32Array(code_length * 2);
            }
            return _audio_chunk;
        }

        this.isEnabled = _isEnabled;

        this.calcRedundantBufferCount = function() {
            if (_scheduled_time !== null &&
                _current_duration !== null) {
                return Math.max(0, Math.floor((_scheduled_time -  _getAudioTime()) / _current_duration));
            } 
            return 0;
        };

        this.getAudioTimer = function() {
            var AudioTimer = function() {
                this.getAudioSyncTime = _getAudioSyncTime;
            };
            return new AudioTimer();
        };

        this.clearState = function() {
            _scheduled_time = null;
            _current_duration = null;
            _scheduled_audio_captured_sec = null;
        };

        this.schedulePCM = function(media_message) {
            var chunk_f32 = media_message.getFloat32Payload(),
                captured_sec = media_message.timestamp_sec + media_message.timestamp_usec / 1e6;
            _scheduleAudio(chunk_f32, captured_sec);
        };

        this.scheduleADPCM = function(media_message) {
            var code_u8 = media_message.getUint8Payload(4),
                code_length = code_u8.length,
                chunk_f32 = _getAudioChunk(code_length),
                captured_sec = media_message.timestamp_sec + media_message.timestamp_usec / 1e6,
                media_message_view = media_message.getViewOfPayload(),
                prevsample = media_message_view.getInt16(0, false),
                previndex = media_message_view.getInt16(2, false),
                i, code, nibble, predsample, index, step, diffq;

            for (i = 0; i < code_length; ++i)  {
                code = code_u8[i];
                nibble = (code >> 4) & 0xf;
                predsample = prevsample;
                index = previndex;
                step = ADPCM_STEP_SIZE_TABLE[index];
                diffq = step >> 3;
                
                if( nibble & 4 ) { diffq += step; }
                if( nibble & 2 ) { diffq += step >> 1; }
                if( nibble & 1 ) { diffq += step >> 2; }
                if( nibble & 8 ) { predsample -= diffq; } else { predsample += diffq; }
                if( predsample > 32767 ) { predsample = 32767; } else if( predsample < -32768 ) { predsample = -32768; }
                index += ADPCM_INDEX_TABLE[nibble];
                if( index < 0 ) { index = 0; }
                if( index > 88 ) { index = 88; }

                prevsample = predsample;
                previndex = index;
                chunk_f32[2 * i] = predsample / 32767.0;

                nibble = code & 0xf;
                predsample = prevsample;
                index = previndex;
                step = ADPCM_STEP_SIZE_TABLE[index];
                diffq = step >> 3;
                
                if( nibble & 4 ) { diffq += step; }
                if( nibble & 2 ) { diffq += step >> 1; }
                if( nibble & 1 ) { diffq += step >> 2; }
                if( nibble & 8 ) { predsample -= diffq; } else { predsample += diffq; }
                if( predsample > 32767 ) { predsample = 32767; } else if( predsample < -32768 ) { predsample = -32768; }
                index += ADPCM_INDEX_TABLE[nibble];
                if( index < 0 ) { index = 0; }
                if( index > 88 ) { index = 88; }

                prevsample = predsample;
                previndex = index;
                chunk_f32[2 * i +  1] = predsample / 32767.0;
            }

            _scheduleAudio(chunk_f32, captured_sec);
        };

        this.onEnableStateChange = function(f) {
            _enabled_state_listener = f;
        };

        this.onScheduledDelay = function(f) {
            _delay_state_listener = f;
        };

        this.unuseAudio = function() {
            if (AudioContext !== global.__undefined) {
                _volume_control.unuse();
                _first_use_control = false;
                _saveVolumeValue(0);
            }
        };

        this.useAudio = function() {
            if (AudioContext !== global.__undefined) {
                _volume_control.use();
                if (hybrid.mobileCheck()) {
                    // Mobile safari requires user interaction to start audio
                    _setVolume(0, true);
                    _volume_control.setValue(0);
                } else {
                    var default_volume = _getSavedVolumeValue();
                    if (_first_use_control === true) {
                        _first_use_control = false;
                        _setVolume(default_volume, true);
                        _volume_control.setValue(default_volume);
                    } else {
                        _notifyEnabledState();
                    }
                }
            }
        };

        if (AudioContext !== global.__undefined) {
            _audio_ctx = new AudioContext();

            if (_audio_ctx.createGain !== global.__undefined) {
                _gain_node = _audio_ctx.createGain();
            } else {
                _gain_node = _audio_ctx.createGainNode();
            }

            _gain_node.connect(_audio_ctx.destination);

            _volume_control.onChange(function(v) {
                _setVolume(v);
                _prev_volume = _getVolume();
            });

            _volume_control.onDragEnd(function(v) {
                _saveVolumeValue(v);
            });

            _volume_control.onTap(function() {
                var volume = 0;
                // Mobile safari won't automatically start audio
                if (hybrid.mobileCheck() && _first_tap) {
                    _dummyPlay();
                    _first_tap = false;
                }
                if (_isEnabled()) {
                    _prev_volume = _getVolume();
                    volume = 0;
                } else {
                    if (hybrid.mobileCheck() || _prev_volume === null) {
                        volume = 1.0;
                    } else {
                        volume = _prev_volume;
                    }
                }

                _setVolume(volume);
                _volume_control.setValue(volume);
                _saveVolumeValue(volume);
            });
        } else {
            _volume_control.unuse();
        }
    };
}(this));
