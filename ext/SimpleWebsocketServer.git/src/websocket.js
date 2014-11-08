(function(global) {
    var @debug(p = global.p,)
        RECONNECT_COOLDOWN_MSEC = 5000,
        RECONNECT_MAX_COUNT = 10;

    // healthcheck_url is used to poll GET request while in retrying state.
    // We separate websocket URL and healthcheck URL for checking existency because
    // some browsers (especially Firefox) extend delays of initiating open()
    // when trying to access the same socket URL.
    // So when you keep retrying to open the same URL, the response may delay like minuites.
    // Since we want to open a socket immediately after the host recovered,
    // We use XHR to check the exisitency of the host.
    global.WebSocketConnection = function(websocket_url,
                                          healthcheck_url,
                                          opt_reconnect_cooldown_msec,
                                          opt_reconnect_max_count) {
        var _websocket_url = websocket_url,
            _healthcheck_url = healthcheck_url,
            that = this,
            _delegate = null,
            _ws = null,
            _opened_ws = null,
            _error_state = false,
            _reconnect_timer = null,
            _reconnect_count = 0,
            _need_reconnect = false,
            _healthchecking = false,
            _connecting = false;

        if (opt_reconnect_cooldown_msec !== global.__undefined) {
            RECONNECT_COOLDOWN_MSEC = opt_reconnect_cooldown_msec;
        }
        if (opt_reconnect_max_count !== global.__undefined) {
            RECONNECT_MAX_COUNT = opt_reconnect_max_count;
        }

        /* delegate {
         *   yourself: Object,
         *   on_open: function(),
         *   on_data: function(Arraybuffer buf),
         *   on_close: function(),
         *   on_error: function(Error e),
         *   on_not_supported: function()
         * }
         */
        function _callDelegateExceptional(label) {
            if (_delegate !== null) {
                var yourself = 'yourself'; // deceive jshint and tame closure cc
                _delegate[label].apply(_delegate[yourself], Array.prototype.slice.call(arguments, 1));
            }
        }

        function _failConnection(e) {
            try {
                _callDelegateExceptional('on_error', e);
            } catch(ee) {
                @log(ee)
            }
            _error_state = true;
            _need_reconnect = false;
            that.close();
        }

        function _callDelegate() {
            try {
                _callDelegateExceptional.apply(this, arguments);
            } catch(e) {
                @log(e)
                if (!_error_state) {
                    _failConnection(e);
                }
            }
        }

        function _open() {
            _connecting = true;

            var ws = new WebSocket(_websocket_url);
            _ws = ws;

            _ws.binaryType = 'arraybuffer';

            _ws.onopen = function() {
                _opened_ws = ws;
                _connecting = false;
                _need_reconnect = false;
                if (_reconnect_timer !== null) {
                    clearTimeout(_reconnect_timer);
                    _reconnect_timer = null;
                }
                _reconnect_count = 0;
                _callDelegate('on_open');
            };

            _ws.onmessage = function(evt) {
                if (evt.data.constructor === ArrayBuffer) {
                    if (_ws === ws) {
                        _callDelegate('on_data', evt.data);
                    }
                }
            };

            _ws.onclose = function() {
                _connecting = false;
                if (_ws === ws) {
                    _ws = null;
                    if (!_error_state) {
                        _callDelegate('on_close');
                    }
                }
            };

            _ws.onerror = function(e) {
                _connecting = false;
                if (_ws === ws) {
                    _ws = null;
                    _callDelegate('on_close', e);
                }
            };
        }

        this.setDelegate = function(delegate) {
            _delegate = delegate;
        };

        this.run = function() {
            if (WebSocket === global.__undefined) {
                _callDelegate('on_not_supported');
                return;
            }

            try {
                _open();
            } catch (e) {
                _failConnection(e);
            }
        };

        this.send = function(data) {
            if (_opened_ws === null) {
                @log('socket is null')
                _failConnection('');
                return;
            }

            try {
                _opened_ws.send(data);
            } catch(e) {
                @log('send failed')
            }
        };

        this.reconnect = function() {
            if (_ws !== null) {
                @log('socket still exists')
                return;
            }

            var rec_reconnect = function() {
                @log('reconnect start')

                if (_ws === null && !_connecting && !_healthchecking) {
                    _reconnect_count += 1;

                    if (_reconnect_count > RECONNECT_MAX_COUNT) {
                        @log('max retry count reached')
                        _failConnection();
                        return;
                    }

                    _healthchecking = true;

                    @log('reconnecting..')
                    try {
                        var xhr = new XMLHttpRequest();
                        xhr.open('GET', _healthcheck_url);
                        xhr.timeout = RECONNECT_COOLDOWN_MSEC * 0.9;
                        xhr.ontimeout = function() {
                            _healthchecking = false;
                        };
                        xhr.onreadystatechange = function() {
                            switch (xhr.readyState) {
                                case 4:
                                    _healthchecking = false;
                                    if (xhr.status === 200) {
                                        _open();
                                    }
                                    break;
                                default:break;
                            }
                        };
                        xhr.send();
                    } catch (e) {
                        _healthchecking = false;
                        _failConnection(e);
                    }
                }
                _reconnect_timer = null;
                if (_need_reconnect) {
                    _reconnect_timer = setTimeout(rec_reconnect, RECONNECT_COOLDOWN_MSEC);
                }
            };

            _need_reconnect = true;

            if (_reconnect_timer === null) {
                rec_reconnect();
            }
        };

        this.close = function() {
            if (_ws === null) {
                @log('no socket to close')
                return;
            }

            try {
                if (_opened_ws === _ws) {
                    var ws = _ws;

                    _ws = null;
                    ws.close();
                }
            } catch(e) {
                @log(e)
            }
            _connecting = false;
        };

        this.failConnection = _failConnection;
    };
}(this));
