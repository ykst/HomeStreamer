(function(global) {
    var View = global.View,
        SettingView = global.SettingView,
        ROIView = global.ROIView,
        ConnectionEffect = global.ConnectionEffect,
        hybrid = global.hybrid,
        storage = global.storage,
        _social_plugin_loaded = false,
        InfoView,
        PasswordView,
        LightControl,
        FocusControl,
        Growl,
        BufferingEffect;

    // TODO: Maybe we should make button class..
    function _lockButton(button) {
        hybrid.addClass(button, 'pressed');
        hybrid.addClass(button, 'unused');
        hybrid.addClass(button, 'locked');
        hybrid.removeClass(button, 'used');
    }

    function _unlockButton(button) {
        hybrid.removeClass(button, 'pressed');
        hybrid.removeClass(button, 'unused');
        hybrid.removeClass(button, 'locked');
        hybrid.addClass(button, 'used');
    }

    function _guardButton(button) {
        if (hybrid.containsClass(button, 'used')) {
            hybrid.addClass(button, 'pressed');
            hybrid.addClass(button, 'locked');
        }
    }

    function _unguardButton(button) {
        if (hybrid.containsClass(button, 'used')) {
            hybrid.removeClass(button, 'pressed');
            hybrid.removeClass(button, 'locked');
        }
    }

    function _armyknifeIsOpen() {
        // TODO: Define armyknife class
        return hybrid.containsClass(document.getElementById('armyknife_container'), 'open');
    }


    InfoView = function(container) {
        this.container = container;

        var _super_appear = this.appear;
        this.appear = function(on_end) {
            if (!_social_plugin_loaded) {
                _social_plugin_loaded = true;
                try {
                    var div = document.createElement('div');
                    div.id = 'fb-root';
                    document.body.appendChild(div);

                    /*jshint ignore:start*/
                    (function(d, s, id) { var js, fjs = d.getElementsByTagName(s)[0]; if (d.getElementById(id)) { return; } js = d.createElement(s); js.id = id; js.src = '//connect.facebook.net/ja_JP/all.js#xfbml=1'; fjs.parentNode.insertBefore(js, fjs); }(document, 'script', 'facebook-jssdk'));

                    (function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs'));
                    /*jshint ignore:end*/
                } catch (e) {
                    global.p(e);
                }
            }

            _super_appear.call(this, on_end);
        };
    };
    InfoView.prototype = new View();

    PasswordView = function(container) {
        this.container = container;

        var _input = hybrid.getChildOfClass(container, 'password_input'),
            _button = hybrid.getChildOfClass(container, 'button'),
            _on_input_end = null,
            _super_appear = this.appear;

        function _endInput() {
            if (_on_input_end !== null) {
                var ref_callback = _on_input_end;
                _on_input_end = null;
                _guardButton(_button);
                ref_callback(_input.value);
            }
        }

        this.appear = function(on_input_end, on_appear_end) {
            if (this.isEnabled()) {
                hybrid.addClass(container, 'shake');
                setTimeout(function() {
                    hybrid.removeClass(container, 'shake');
                }, 500);
            }

            _unguardButton(_button);
            _on_input_end = on_input_end; 
            _super_appear.call(this, on_appear_end);

            if (!hybrid.mobileCheck()) {
                _input.focus();
            }
        };

        _input.addEventListener('focus', function() {
            hybrid.removeClass(_input, 'hint');
            if (_input.type !== "password") {
                _input.type = "password";
                _input.value = "";
            }
        });

        _input.addEventListener('keydown', function(evt) {
            if (evt.keyCode === 13) {
                _endInput();
            }
        });

        hybrid.onTap(_button, function() {
            _endInput();
        });
    };
    PasswordView.prototype = new View();

    LightControl = function() {
        var _button = document.getElementById('light_button'),
            _img = hybrid.getChildOfID(_button, 'light_button_img'),
            _stat = 2;

        this.container = _button;

        this.onTap = function(on_tap) {
            hybrid.onTap(_button, function() {
                if (_stat !== 2 &&
                    hybrid.containsClass(_button, 'used') &&
                    !hybrid.containsClass(_button, 'locked')) {
                    on_tap();
                }
            });
        };

        this.guard = function() {
            _guardButton(_button);
        };

        this.unguard = function() {
            _unguardButton(_button);
        };

        this.setStatus = function(stat) {
            switch (stat) {
                case 0:
                    _img.src = 'light_off.png';
                    _unlockButton(_button);
                    break;
                case 1:
                    _img.src = 'light_on.png';
                    _unlockButton(_button);
                    break;
                case 2:
                    _img.src = 'light_off.png';
                    _lockButton(_button);
                    break;
                default: break;
            }

            _stat = stat;

            if (!_armyknifeIsOpen()) {
                hybrid.addClass(_button, 'locked');
            }
        };

        this.getStatus = function() {
            return _stat;
        };
    };
    LightControl.prototype = new View();

    Growl = function() {
        var _pane = document.getElementById('growl'),
            _span = hybrid.getChildOfID(_pane, 'growl_text'),
            _text = null,
            _appearing = false,
            _current_timer = null,
            that = this;

        this.container = _pane;

        this.growlText = function(text) {
            _text = text;
            _span.textContent = text;
            _appearing = true;

            if (_current_timer !== null) {
                clearTimeout(_current_timer);
            }

            this.appear(function() {
                _appearing = false;

                _current_timer = setTimeout(function() {
                    _current_timer = null;
                    if (!_appearing) {
                        that.disappear();
                    }
                }, 1500);
            });
        };
    };
    Growl.prototype = new View();

    FocusControl = function(growl) {
        var _button = document.getElementById('focus_button'),
            _img = hybrid.getChildOfID(_button, 'focus_button_img'),
            _stat = 2;

        function _showStatus() { 
            switch (_stat) {
                case 0:
                    growl.growlText('$_$DESC_FOCUS_LOCKED$_$');
                    break;
                case 1:
                    growl.growlText('$_$DESC_FOCUS_AUTO$_$');
                    break;
                default: break;
            }
        }

        this.container = _button;

        this.onTap = function(on_tap) {
            hybrid.onTap(_button, function() {
                if (_stat !== 2 &&
                    hybrid.containsClass(_button, 'used') &&
                    !hybrid.containsClass(_button, 'locked')) {
                    on_tap();
                }
            });
        };

        this.guard = function() {
            _guardButton(_button);
        };

        this.unguard = function() {
            _unguardButton(_button);
        };

        this.setStatus = function(stat, show_status) {
            switch (stat) {
                case 0:
                    _img.src = 'focus_locked.png';
                    _unlockButton(_button);
                    break;
                case 1:
                    _img.src = 'focus.png';
                    _unlockButton(_button);
                    break;
                case 2:
                    _img.src = 'focus_locked.png';
                    _lockButton(_button);
                    break;
                default: break;
            }

            var prev_stat = _stat,
                changed = _stat !== stat;

            _stat = stat;

            if (changed && (show_status === true) && (prev_stat !== 2)) {
                _showStatus();
            }

            if (!_armyknifeIsOpen()) {
                hybrid.addClass(_button, 'locked');
            }
        };

        this.getStatus = function() {
            return _stat;
        };
    };
    FocusControl.prototype = new View();
    
    BufferingEffect = function() {
        this.container = document.getElementById('buffering_indicator');
    };
    BufferingEffect.prototype = new View();

    global.SceneManager = function() {
        var _views = {
                setting: {button:document.getElementById('setting_button'), 
                          ctrl:new SettingView()},
                roi: {button:document.getElementById('roi_button'),
                      ctrl:new ROIView()},
                info: {button:document.getElementById('info_button'),
                       ctrl: new InfoView(document.getElementById('info_dialog'))}
            },
            _guard = new ConnectionEffect(),
            _buffering = new BufferingEffect(),
            _password_view = new PasswordView(document.getElementById('password_view')),
            _background = document.getElementById('container'),
            _current_view = null,
            _toolbar_bottom = View.elemToView(document.getElementById('toolbar_bottom')), 
            _armyknife = View.elemToView(document.getElementById('armyknife')),
            _growl = new Growl(),
            _picture_url_delegate = null,
            _screen = document.getElementById('screen'),
            _screen_state = 0;

        function _dismissMobileKeyboard() {
            document.activeElement.blur();
            window.scroll(0,0);
        }

        function _fullScreen() {
            hybrid.addClass(_screen, 'full');
        }

        function _fitScreen() {
            hybrid.removeClass(_screen, 'full');

            var aspect_ratio_ratio = ((window.innerWidth / window.innerHeight) / (_screen.width / _screen.height)),
                height_fit = aspect_ratio_ratio > 1.0,
                percent;

            if (height_fit) {
                aspect_ratio_ratio = 1.0 / aspect_ratio_ratio;
            }

            percent = aspect_ratio_ratio * 100.0;

            _screen.style.minWidth = null;
            _screen.style.minHeight = null;
            _screen.style.width = null;
            _screen.style.height = null;

            _screen.style.minWidth = String(percent) + '%';
            _screen.style.minHeight = String(percent) + '%';

            if (height_fit) {
                _screen.style.height = '100%';
            } else {
                _screen.style.width = '100%';
            }
        }

        function _originalScreen() {
            hybrid.removeClass(_screen, 'full');
            _screen.style.minWidth = null;
            _screen.style.minHeight = null;
            _screen.style.width = null;
            _screen.style.height = null;
        }

        function _screenAdjustment() {
            switch (_screen_state) {
                case 0: // now full screen
                    _fullScreen();
                    break;
                case 1: // now fit screen
                    _fitScreen();
                    break;
                case 2: // now original screen
                    _originalScreen();
                    break;
                default:
                    break;
            }
        }

        this.dismissMobileKeyboard = _dismissMobileKeyboard;

        this.getROIView = function() {
            return _views.roi.ctrl;
        };

        this.getSettingView = function() {
            return _views.setting.ctrl;
        };

        this.showPasswordView = function(on_end) {
            _password_view.appear(on_end); 
        };

        this.clearPasswordView = function(on_end) {
            _password_view.disappear(on_end); 
        };

        this.clearGuard = function() {
            if (_guard.isEnabled()) { 
                _guard.disappear();
            }
        };

        this.errorGuard = function() {
            _password_view.disappear();
            _dismissMobileKeyboard();
            _buffering.disappear();
            _guard.error();
        };

        this.connectingGuard = function() {
            _guard.connecting();
        };

        this.bufferingEffect = function() {
            if (!_buffering.isEnabled()) {
                _buffering.appear();
            }
        };

        this.clearBufferingEffect = function() {
            if (_buffering.isEnabled()) {
                _buffering.disappear();
            }
        };

        this.clearCurrentView = function() {
            if (_current_view !== null) {
                var view = _current_view;
                _current_view = null;
                view.ctrl.disappear();
            }
        };

        this.screenAspectChanged = function() {
            _screenAdjustment();
        };

        // FIXME: should make delegate and detach this
        this.genLightControl = function(stat) {
            var light_control = new LightControl();
            light_control.appear();
            light_control.setStatus(stat);
            return light_control;
        };

        this.genFocusControl = function(stat) {
            var focus_control = new FocusControl(_growl);
            focus_control.appear();
            focus_control.setStatus(stat);
            return focus_control;
        };

        this.setPictureURLDelegate = function(delegate) {
            _picture_url_delegate = delegate;
        };

        (function() {
            function handleTap(view) { 
                return function() {
                    if (_current_view !== view) {
                        var seq = function() {
                            view.ctrl.appear(); 
                        };

                        if (_current_view !== null) {
                            _current_view.ctrl.disappear();
                        }

                        _current_view = view;
                        seq();
                    } else {
                        _current_view = null;

                        view.ctrl.disappear();
                    }
                };
            }

            var label,
                view;
            
            for (label in _views) {
                if (_views.hasOwnProperty(label)) {
                    view = _views[label];
                    hybrid.onTap(view.button, handleTap(view));
                }
            }
        }());

        (function() {
            var _fullscreen_button = document.getElementById('screen_change_button'),
                _icon = hybrid.getChildOfID(_fullscreen_button, 'fullscreen_button_img'),
                _saved_state = storage.get('screen_mode'),
                _to_full_image = 'full-screen.png',
                _to_fit_image = 'fit-screen.png',
                _to_minimum_image = 'full-screen-exit.png';

            hybrid.onTap(_fullscreen_button, function() {
                switch (_screen_state) {
                    case 0: // now full screen
                        _icon.src = _to_minimum_image;
                        _screen_state = 1;
                        break;
                    case 1: // now fit screen
                        _screen_state = 2;
                        _icon.src = _to_full_image;
                        break;
                    case 2: // now original screen
                        _icon.src = _to_fit_image;
                        _screen_state = 0;
                        break;
                    default:
                        break;
                }

                storage.set('screen_mode', _screen_state);

                _screenAdjustment();
            });

            if (_saved_state !== null) {
                switch (parseInt(_saved_state, 10)) {
                    case 0:
                        _icon.src = _to_fit_image;
                        _screen_state = 0;
                        _screenAdjustment();
                        break;
                    case 1:
                        _icon.src = _to_minimum_image;
                        _screen_state = 1;
                        _screenAdjustment();
                        break;
                    case 2:
                        _icon.src = _to_full_image;
                        _screen_state = 2;
                        _screenAdjustment();
                        break;
                    default:
                        _icon.src = _to_fit_image;
                        break;
                }
            } else { 
                _icon.src = _to_fit_image;
            }
        }());

        (function() {
            var _armyknife_button = document.getElementById('armyknife_opener'),
                _armyknife_container = document.getElementById('armyknife_container'),
                _opener_image = hybrid.getChildOfID(_armyknife_button, 'armyknife_opener_img'),
                _opener_image_srcs = ["armyknife_open.png", "armyknife_close.png"],
                _saved_state = storage.get('armyknife'),
                _open_state = 0;

            function _handleButtonLocks(enable_lock) {
                hybrid.iterateChildren(_armyknife_container, function(elem) {
                    if (elem.id !== 'armyknife_opener') {
                        if (enable_lock) {
                            if (hybrid.containsClass(elem, 'button')) {
                                hybrid.addClass(elem, 'locked');
                                hybrid.removeClass(elem, 'used');
                            }
                        } else {
                            if (hybrid.containsClass(elem, 'button') && 
                                !hybrid.containsClass(elem, 'unused')) {
                                hybrid.removeClass(elem, 'locked');
                                hybrid.addClass(elem, 'used');
                            }
                        }
                    }
                });
            }

            hybrid.onTap(_armyknife_button, function() {
                switch (_open_state) {
                    case 0:
                        hybrid.addClass(_armyknife_container, 'open');

                        _handleButtonLocks(false);

                        _open_state = 1;
                        break;
                    case 1:
                        hybrid.removeClass(_armyknife_container, 'open');

                        _handleButtonLocks(true);

                        _open_state = 0;
                        break;
                    default:
                        break;
                }

                storage.set('armyknife', _open_state);

                _opener_image.src = _opener_image_srcs[_open_state];
            });

            if (parseInt(_saved_state, 10) === 1) {
                _open_state = 1; 
                _opener_image.src = _opener_image_srcs[_open_state];

                hybrid.addClass(_armyknife_container, 'notransition');
                hybrid.addClass(_armyknife_container, 'open');
                /*jshint ignore:start*/
                _saved_state = _armyknife_container.offsetHeight; // Trigger reflow
                _saved_state = _open_state;
                /*jshint ignore:end*/
                hybrid.removeClass(_armyknife_container, 'notransition');
                _handleButtonLocks(false);
            } else {
                _handleButtonLocks(true);
            }
        }());

        (function() {
            function downloadPicture(filename) {
                if (_picture_url_delegate === null) { return; }

                var lnk = document.createElement('a'),
                    d = "download",
                    e;

                lnk[d] = filename; // for closure cc acvanced opt
                lnk.href = _picture_url_delegate(); //canvas.toDataURL();
                lnk.setAttribute("target", "_blank");

                if (document.createEvent) {
                    e = document.createEvent("MouseEvents");
                    e.initMouseEvent("click", true, true, window,
                            0, 0, 0, 0, 0, false, false, false,
                            false, 0, null);

                    lnk.dispatchEvent(e);
                } else if (lnk.fireEvent) {
                    lnk.fireEvent("onclick");
                }
            }

            function genFileName() {
                return (new Date()).toString() + '.jpg';
            }

            var button = document.getElementById('still_camera_button');

            hybrid.onTap(button, function() {
                if (!hybrid.containsClass(button, 'locked')) {
                    downloadPicture(genFileName());
                }
            });
        }());

        hybrid.iterateChildren(document.body, function(c) {
            if (hybrid.containsClass(c, 'button') && 
                !hybrid.containsClass(c, 'unused')) {
                hybrid.addClass(c, 'used');
                hybrid.onTap(c, function() {
                    if (!hybrid.containsClass(c, 'locked')) {
                        hybrid.addClass(c, 'tapped');
                    }
                }, function() {
                    hybrid.removeClass(c, 'tapped');
                });
            }
        });

        // prevent double-tap scroll
        _background.ontouchend = function(event) {
            event.preventDefault();
        };

        _background.onclick = function(event) {
            event.preventDefault();
        };

        hybrid.onTap(_background, function() {
            if (_current_view !== null) {
                _current_view.ctrl.disappear();
                _current_view = null;
            } else {
                _toolbar_bottom.toggleAppear();
                _armyknife.toggleAppear();
            }
        });

        hybrid.onWindowResize(function() {
            _screenAdjustment();
        });

        _views.setting.ctrl.dismiss();
        _views.roi.ctrl.dismiss();
        _views.info.ctrl.dismiss();
    };
}(this));
