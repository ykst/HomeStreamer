(function(global) {
    var SWSControlMessage = global.SWSControlMessage,
        Message = global.Message,
        SERVER_TIMEOUT_MSEC = 10000,
        TIMEOUT_POLL_INTERVAL_MSEC = 2000,
        INPUT_SIGNAL_INTERVAL_MSEC = 1000,
        INIT = 0,
        INPUT = 1,
        UNLOCKED = 2,
        TERMINATED = 99;

    global.SWSClientStateMachine = function(socket) {
        var _at = INIT,
            _socket = socket,
            _server_timeout_start_msec = null,
            _input_signal_timer = null,
            _timeout_check_timer = null,
            _delegate = null,
            _password_seed = null,
            _ctrl_message = new SWSControlMessage();

        /* delegate {
         *   yourself: Object,
         *   on_timeout: function(),
         *   on_authorized: function(),
         *   on_password_request: function(),
         * }
         */
        function _callDelegateExceptional(label) {
            if (_delegate !== null) {
                var yourself = 'yourself'; // deceive jshint and tame closure cc
                _delegate[label].apply(_delegate[yourself], Array.prototype.slice.call(arguments, 1));
            }
        }

        function _clearTimers() {
            if (_timeout_check_timer !== null) {
                clearTimeout(_timeout_check_timer);
                _timeout_check_timer = null;
            }

            if (_input_signal_timer !== null) {
                clearTimeout(_input_signal_timer);
                _input_signal_timer = null;
            }
        }

        function _resetServerTimeout() {
            _server_timeout_start_msec = (new Date()).getTime();
        }

        function _checkServerDidTimeout() {
            var did_timeout = false,
                current_time_msec;

            if (_server_timeout_start_msec !== null) {
                current_time_msec = (new Date()).getTime();
                if (current_time_msec - _server_timeout_start_msec > SERVER_TIMEOUT_MSEC) {
                    did_timeout = true;
                }
            }

            return did_timeout;
        }

        function _startCheckTimeout() {
            var f = function() {
                _timeout_check_timer = null;

                if (_at !== TERMINATED) {
                    if (_checkServerDidTimeout()) {
                        @log('server timeout')
                        _callDelegateExceptional('on_timeout');
                    } else {
                        _timeout_check_timer = setTimeout(f, TIMEOUT_POLL_INTERVAL_MSEC);
                    }
                }
            };

            _timeout_check_timer = setTimeout(f, TIMEOUT_POLL_INTERVAL_MSEC);
        }

        function _invalidateServerTimeout() {
            _server_timeout_start_msec = null;
        }

        function _startPasswordInputSignal() {
            var f = function() {
                _input_signal_timer = null;
                if (_at === INPUT) {
                    _socket.send(_ctrl_message.waitingInput());
                    _input_signal_timer = setTimeout(f, INPUT_SIGNAL_INTERVAL_MSEC);
                }
            };

            if (_at === INPUT) {
                _input_signal_timer = setTimeout(f, INPUT_SIGNAL_INTERVAL_MSEC);
            }
        }

        function _handleCtrlMessage(message) {
            var processed = false;

            switch (message.type) {
                case SWSControlMessage.SWS_CTRL_BIL_HELLO:
                    if (_at === INIT || _at === INPUT) {
                        _at = UNLOCKED;
                        _callDelegateExceptional('on_authorized');
                    }

                    processed = true;
                    break;
                case SWSControlMessage.SWS_CTRL_S2C_PASSWORD_REQUIRED:
                    if (_at === INIT) {
                        _at = INPUT;
                        _startPasswordInputSignal();
                    }

                    SWSControlMessage.readPasswordSeed(message, function(seed) {
                        _password_seed = seed;
                        _callDelegateExceptional('on_password_request');
                    });
                    processed = true;
                    break;
                case SWSControlMessage.SWS_CTRL_S2C_WAITING_INPUT:
                    @log("server waiting input")
                    processed = true;
                    break;
                case SWSControlMessage.SWS_CTRL_S2C_RESET:
                    @throw('server reset')
                default: 
                    @log('not handled')
                    break;
            }

            return processed;
        }

        function _onOpen() {
            @log('on open')
            _invalidateServerTimeout();
            _clearTimers();
            _startCheckTimeout();
            _socket.send(_ctrl_message.hello());
        }

        function _onError() {
            @log('on error')
            if (_at !== TERMINATED) {
                _at = TERMINATED;
                _clearTimers();
            }
        }

        function _onClose() {
            @log('on close')
            if (_at !== TERMINATED) {
                _at = INIT;
                _clearTimers();
            }
        }

        function _onData(data) {
            @log('on data')
            var message = new Message(data);
            return _onMessage(message);
        }

        function _onMessage(message) {
            var processed = false;

            _resetServerTimeout();

            switch (message.category) {
                case SWSControlMessage.CATEGORY: 
                    processed = _handleCtrlMessage(message);
                    break;
                default: 
                    @log('not handled')
                    break;
            }

            return processed;
        }

        function _onNotSupported() {
            @log('not supported')
            _onError();
        }

        this.onOpen = _onOpen;
        this.onError = _onError;
        this.onClose = _onClose;
        this.onData = _onData;
        this.onMessage = _onMessage;
        this.onNotSupported = _onNotSupported;

        this.sendPassword = function(plain_text) {
            _socket.send(_ctrl_message.password(plain_text, _password_seed));
            _socket.send(_ctrl_message.hello());
            _password_seed = null;
        };

        this.setDelegate = function(delegate) {
            _delegate = delegate;
        };

        this.run = function() {
            _socket.run();
        };
    };
}(this));
