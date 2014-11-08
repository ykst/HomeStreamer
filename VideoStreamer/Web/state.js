(function(global) {
    var @debug(p = global.p,)
        Message = global.Message,
        MediaStream = global.MediaStream,
        ControlMessage = global.ControlMessage,
        ControlMessageFactory = global.ControlMessageFactory,
        CLIENT_REPORT_INTERVAL_MSEC = 1000,
        INIT = 0,
        QUERY_SPEC = 1,
        STREAMING = 2,
        TERMINATED = 99;

    global.ClientStateMachine = function(video_player, audio_player, scene_manager, socket) {
        var _at = INIT,
            _socket = socket,
            _parent = new global.SWSClientStateMachine(_socket),
            _audio_player = audio_player,
            _audio_discontinued_count = 0,
            _prev_audio_discontinued_count = 0,
            _light_control = null,
            _scene_manager = scene_manager,
            _video_player = video_player,
            _video_received_times = 0,
            _prev_video_received_times = 0,
            _processed_frames = 0,
            _prev_processed_frames = 0,
            _ctrl_factory = new ControlMessageFactory(),
            _server_video_disabled = false,
            _delay_effect_ref_count = 0,
            _delay_first_time = true,
            _client_report_timer = null,
            _focus_control = null;

        function _increaseReportFrame() {
            _processed_frames += 1;
        }

        function _changeROIRect(roi) {
            _socket.send(_ctrl_factory.setROI(roi));
        }

        function _changeOrientation() {
            _socket.send(_ctrl_factory.changeOrientation());
        }

        function _calcDeltaProcessedFrame() {
            var ret = _processed_frames - _prev_processed_frames;
            _prev_processed_frames = _processed_frames;
            return ret;
        }

        function _increaseVideoReceived() {
            _video_received_times += 1;
        }

        function _calcDeltaVideoReceived() {
            var ret = _video_received_times - _prev_video_received_times;
            _prev_video_received_times = _video_received_times;
            return ret;
        }

        function _calcDeltaAudioDiscontinuedCount() {
            var ret = _audio_discontinued_count - _prev_audio_discontinued_count;
            _prev_audio_discontinued_count = _audio_discontinued_count;
            return ret;
        }

        function _getAudioRedundantBufferCount() {
            return _audio_player.calcRedundantBufferCount();
        }

        function _videoStatistics() {
            var f = (function() {
                return function() {
                    if (_video_player.pollFrameUpdate()) {
                        _increaseReportFrame();
                    }

                    if (_server_video_disabled) {
                        if (_at === STREAMING) {
                            _socket.send(_ctrl_factory.requestIFrame());
                        }
                        _server_video_disabled = false;
                    }

                    if (_at === STREAMING) {
                        global.displayLink(f);
                    }
                };
            }());

            global.displayLink(f);
        }

        function _startClientReport() {
            var f = function() {
                _client_report_timer = null;

                if (_at === STREAMING) {
                    _socket.send(_ctrl_factory.report(_calcDeltaProcessedFrame(), 
                                                _calcDeltaVideoReceived(),
                                                _calcDeltaAudioDiscontinuedCount(),
                                                _getAudioRedundantBufferCount())); 
                    _client_report_timer = setTimeout(f, CLIENT_REPORT_INTERVAL_MSEC);
                }
            };

            _client_report_timer = setTimeout(f, CLIENT_REPORT_INTERVAL_MSEC);
        }

        function _clearTimers() {
            if (_client_report_timer !== null) {
                clearTimeout(_client_report_timer);
                _client_report_timer = null;
            }
        }

        function _clearStatistics() {
            _processed_frames = 0;
            _prev_processed_frames = 0;

            _video_received_times = 0;
            _prev_video_received_times = 0;

            _audio_discontinued_count = 0;
            _prev_audio_discontinued_count = 0;

            _delay_first_time = true;
        }

        function _onTimeout() {
            _resetConnection();
        }

        function _onPasswordRequest() {
            _scene_manager.showPasswordView(_parent.sendPassword);
        }

        function _onAuthorized() {
            if (_at === INIT) {
                _scene_manager.clearPasswordView();
                _scene_manager.dismissMobileKeyboard();
                _socket.send(_ctrl_factory.querySpec());
                _at = QUERY_SPEC;
            }
        }

        function _onOpen() {
            _parent.onOpen();
            _clearTimers();
            _clearStatistics();
            _audio_player.clearState();
            _scene_manager.clearCurrentView();
            _scene_manager.connectingGuard();
        }

        function _onError(@debug(evt)) {
            _parent.onError();
            _at = TERMINATED;
            _clearTimers();
            _scene_manager.errorGuard();
            @log("onerror: " + evt||'undefind')
        }

        function _onClose() {
            _parent.onClose();
            if (_at !== TERMINATED) {
                _at = INIT;
                _scene_manager.clearPasswordView();
                _clearTimers();
                _scene_manager.connectingGuard();
                _socket.reconnect();
            }
        }

        function _resetConnection() {
            _socket.close();
            _onClose();
        }

        function _handleMediaStreamMessage(message) {
            if (_at !== STREAMING) {
                @throw('streaming not ready')
            }

            switch (message.type) {
                case MediaStream.TYPE_AUDIO_PCM:
                    _audio_player.schedulePCM(message);
                    break;
                case MediaStream.TYPE_AUDIO_ADPCM:
                    _audio_player.scheduleADPCM(message);
                    break;
                case MediaStream.TYPE_VIDEO_JPG: // Fallthrough
                case MediaStream.TYPE_VIDEO_DIFFJPG:
                    _scene_manager.clearGuard();
                    _increaseVideoReceived();
                    _video_player.scheduleVideo(message);
                    break;
                default:
                    @throw('unsupported MediaStream: ' + message.type)
            }
        }

        function _handleFocusControl(focus_status) {
            if (_focus_control === null) {
                _focus_control = _scene_manager.genFocusControl(focus_status);
                _focus_control.onTap(function() {
                    var stat = _focus_control.getStatus();

                    if (stat === 0 || stat === 1) {
                        _focus_control.guard();
                        _socket.send(_ctrl_factory.focusControl(1 - stat));
                    }
                });
            } else {
                _focus_control.unguard();
                _focus_control.setStatus(focus_status, true);
            }
        }

        function _handleCtrlMessage(message) {
            switch (message.type) {
                case ControlMessageFactory.CTRL_S2C_REPORT:
                    @log("server report")
                    break;
                case ControlMessageFactory.CTRL_S2C_SHOW_SPEC:
                    (new ControlMessage(message)).readSetting(function(setting) {
                        _video_player.setDisplay(setting.capture_width, setting.capture_height);

                        var setting_view = _scene_manager.getSettingView(),
                            roi_view = _scene_manager.getROIView();
                        setting_view.setValues(setting.resolution_level, setting.sound_buffering_level, setting.contrast_adjustment_level);
                        setting_view.setScreenSize(setting.screen_width, setting.screen_height);

                        roi_view.setDisplaySize(setting.capture_width, setting.capture_height);
                        roi_view.setROI(setting.roi);

                        _scene_manager.screenAspectChanged();

                        if (_at === QUERY_SPEC) {
                            _socket.send(_ctrl_factory.startStreaming());
                            _at = STREAMING;

                            _videoStatistics();
                            _startClientReport();    
                        }
                    });
                    break;
                case ControlMessageFactory.CTRL_S2C_FOCUS_STATUS:
                    (new ControlMessage(message)).readOctetStatus(function(focus_status) {
                        _handleFocusControl(focus_status);
                    });

                    break;
                case ControlMessageFactory.CTRL_S2C_LIGHT_STATUS:
                    (new ControlMessage(message)).readOctetStatus(function(stat) {
                        if (_light_control === null) {
                            _light_control = _scene_manager.genLightControl(stat);
                            _light_control.onTap(function() {
                                var stat = _light_control.getStatus();

                                if (stat === 0 || stat === 1) {
                                    _light_control.guard();
                                    _socket.send(_ctrl_factory.lightControl(1 - stat));
                                }
                            });
                        } else {
                            _light_control.unguard();
                            _light_control.setStatus(stat);
                        }
                    });

                    break;
                case ControlMessageFactory.CTRL_S2C_VIDEO_DISABLED:
                    @log('get disabled message')
                    _server_video_disabled = true;
                    break;
                case ControlMessageFactory.CTRL_S2C_AUDIO_USE:
                    _audio_player.useAudio();
                    break;
                case ControlMessageFactory.CTRL_S2C_AUDIO_UNUSE:
                    _audio_player.unuseAudio();
                    break;
                default:
                    @throw('unsupported ControlMessage: ' + message.type)
            }
        }

        function _onData(data) {

            var message = new Message(data);

            if (_parent.onMessage(message) === true) { return; }

            switch (message.category) {
                case MediaStream.CATEGORY:
                    _handleMediaStreamMessage(message);
                    break;
                case ControlMessageFactory.CATEGORY: 
                    _handleCtrlMessage(message);
                    break;
                default: 
                    @throw('unknown category: ' + message.category)
                     
            }
        }

        function _onNotSupported() {
            _parent.onNotSupported();
            @throw('websocket not supported')
        }

        this.run = function() {
            _socket.run();
        };

        _socket.setDelegate({
            'yourself': this,
            'on_open': _onOpen,
            'on_error': _onError,
            'on_close': _onClose,
            'on_data': _onData,
            'on_not_supported': _onNotSupported
        });

        _parent.setDelegate({
            'yourself': this,
            'on_timeout': _onTimeout,
            'on_authorized': _onAuthorized,
            'on_password_request': _onPasswordRequest
        });

        _scene_manager.setPictureURLDelegate(function() {
            return _video_player.getLatestObjectURL();
        });

        _audio_player.onEnableStateChange(function(is_enabled) {
            _socket.send(_ctrl_factory.audioControl(is_enabled));
        });

        _audio_player.onScheduledDelay(function(delta_sec) {
            if ((!_delay_first_time) || (delta_sec > 0.5)) {
                _scene_manager.bufferingEffect();
                _delay_effect_ref_count += 1;
                setTimeout(function() {
                    _delay_effect_ref_count -= 1;
                    if (_delay_effect_ref_count <= 0) {
                        _delay_effect_ref_count = 0;
                        _scene_manager.clearBufferingEffect();
                    }
                },  delta_sec * 1000.0 + 500);
            }
            _delay_first_time = false;
        });

        (function() {
            var roi_view = _scene_manager.getROIView(),
                setting_view = _scene_manager.getSettingView();

            roi_view.onChange(function(roi) {
                _changeROIRect(roi);
            });

            roi_view.onChangeOrientation(function() {
                _changeOrientation();
            });

            setting_view.onChange(function(video_quality_level, sound_buffering_level, contrast_adjustment_level) {
                var levels = {
                    video_quality: video_quality_level,
                    sound_buffering: sound_buffering_level,
                    contrast_adjustment: contrast_adjustment_level
                };

                _socket.send(_ctrl_factory.setLevels(levels));
            });
        }());
    };
}(this));
