(function(global) {
    var hybrid = global.hybrid,
        View = global.View,
        Shape, 
        CanvasState;
    
    Shape = function(cx, cy, scale, degree, display_width, display_height) {
        var _display_width = display_width,
            _display_height = display_height,
            _x = cx,
            _y = cy,
            _scale = scale,
            _degree = degree,
            _maximum_scale;

        function _calcNextMaximumScale(check_p) {
            function lineIntersection(a, b, c, d) {
                var denom = (b.x - a.x) * (d.y - c.y) - (b.y - a.y) * (d.x - c.x),
                    num_r, num_s, r, s;

                if (denom === 0) {
                    return null;
                }

                num_r = (a.y - c.y) * (d.x - c.x) - (a.x - c.x) * (d.y - c.y);
                num_s = (a.y - c.y) * (b.x - a.x) - (a.x - c.x) * (b.y - a.y);

                r = num_r / denom;
                s = num_s / denom;

                if (r < 0 || r > 1 || s < 0 || s > 1) {
                    return null;
                }

                return {
                    x: a.x + r * (b.x - a.x),
                    y: a.y + r * (b.y - a.y)
                };
            }

            function calcMaximumScale(center, degree, size) {
                var line_table = [
                        [{x:0, y:0}, {x:size.width, y:0}],
                        [{x:size.width, y:0}, {x:size.width, y:size.height}],
                        [{x:0, y:0}, {x:0, y:size.height}],
                        [{x:0, y:size.height}, {x:size.width, y:size.height}]
                    ],
                    hw = size.width / 2.0,
                    hh = size.height / 2.0,
                    corner_table = [
                        {x: -hw, y: -hh},
                        {x: hw, y: -hh},
                        {x: hw, y: hh},
                        {x: -hw, y: hh}
                    ],
                    rad = degree * Math.PI / 180.0,
                    sin = Math.sin(rad),
                    cos = Math.cos(rad),
                    max_dist2 = hw * hw + hh * hh,
                    min_dist2 = max_dist2,
                    i, p, corner, j, ls, le, ip, dx, dy, dist;

                for (i = 0; i < 4; ++i) {
                    p = corner_table[i];
                    corner = {x: p.x * cos - p.y * sin + center.x,
                                  y: p.x * sin + p.y * cos + center.y};

                    for (j = 0; j < 4; ++j) {
                        ls = line_table[j][0];
                        le = line_table[j][1];

                        ip = lineIntersection(ls, le, center, corner);

                        if (ip !== null) {
                            dx = ip.x - center.x;
                            dy = ip.y - center.y;
                            dist = dx * dx + dy * dy;

                            min_dist2 = Math.min(dist, min_dist2);
                        }
                    }
                }

                return Math.sqrt(min_dist2 / max_dist2);
            }

            return calcMaximumScale({
                    x: check_p.x * _display_width,
                    y: check_p.y * _display_height
                }, 
                _degree, 
                {width:_display_width, height:_display_height});
        }

        function _calcMaximumScale() {
            return _calcNextMaximumScale({x: _x, y: _y});
        }

        function _updateMaximumScale() {
            _maximum_scale = _calcMaximumScale();
            return _maximum_scale;
        }

        function _addDegree(delta_degree) {
            var next_degree = _degree + delta_degree % 360;

            next_degree = next_degree % 360;

            if (next_degree < 360) {
                next_degree += 360;
            } 

            _degree = next_degree;
            _scale = Math.min(_scale, _updateMaximumScale());
        }

        function _calcMargin() {
            var rad = _degree * Math.PI / 180.0,
                cos = Math.abs(Math.cos(rad)),
                sin = Math.abs(Math.sin(rad)),
                dw = _display_width * _scale,
                dh = _display_height * _scale;

            return { y: (dw * sin + dh * cos) / 2,
                     x: (dw * cos + dh * sin) / 2};
        }

        function _calcNextPosition(p) {
            var margin = _calcMargin(),
                x = p.x * _display_width,
                y = p.y * _display_height,
                ml = x - margin.x,
                mr = _display_width - (x + margin.x),
                mt = y - margin.y,
                mb = _display_height - (y + margin.y),
                collision = {x:null, y:null};

            if (ml < 0) {
                x -= ml;
                collision.x = margin.x;
            }

            if (mr < 0) {
                x += mr;
                if (collision.x !== null) {
                    x = _display_width / 2;
                } else {
                    collision.x = _display_width - margin.x;
                }
            }

            if (mt < 0) {
                y -= mt;
                collision.y = margin.y;
            }

            if (mb < 0) {
                y += mb;
                if (collision.y !== null) {
                    y = _display_height / 2;
                } else {
                    collision.y = _display_height - margin.y;
                }
            }

            return {x: x / _display_width,
                    y: y / _display_height,
                    collision: collision};
        }

        this.getShape = function() {
            return { x:_x, y:_y, scale:_scale, degree:_degree };
        };

        this.getX = function() {
            return _x;
        };

        this.getY = function() {
            return _y;
        };

        this.setDisplayWidth = function(w) {
            _display_width = w;
        };

        this.setDisplayHeight = function(h) {
            _display_height = h;
        };

        this.draw = function(ctx) {
            var width = _display_width * _scale,
                height = _display_height * _scale,
                hw = width / 2,
                hh = height / 2,
                fills = ['rgba(0, 235, 235, 0.5)', 'rgba(0, 255, 255, 0.5)'],
                triangles, i;

            ctx.save();
            ctx.translate(_x * _display_width, _y * _display_height);
            ctx.rotate(Math.floor(_degree) * Math.PI / 180.0);

            if (width > height) {
                triangles = [[[-hw, hh], [hw, -hh], [hw, hh]],
                             [[-hw, -hh], [hw, -hh], [-hw, hh]]];
            } else {
                triangles = [[[-hw, -hh], [hw, hh], [-hw, hh]],
                             [[-hw, -hh], [hw, hh], [hw, -hh]]];
            }

            for (i = 0; i < 2; ++i) {
                ctx.fillStyle = fills[i];
                ctx.beginPath();
                ctx.moveTo(triangles[i][0][0], triangles[i][0][1]);
                ctx.lineTo(triangles[i][1][0], triangles[i][1][1]);
                ctx.lineTo(triangles[i][2][0], triangles[i][2][1]);
                ctx.fill();
            }

            ctx.restore();
        };

        this.addDegree = _addDegree;

        this.addStepDegree = function(step_degree) {
            if (step_degree === 0) {
                return;
            }

            if (step_degree > 0) {
                _addDegree(step_degree - (_degree % step_degree));
            } else {
                var test_degree = -(_degree % (-step_degree));
                _addDegree(test_degree === 0 ? step_degree : test_degree);
            }
        };

        this.changePosition = function(p) {
            var result = _calcNextPosition(p);

            _x = result.x;
            _y = result.y;

            _updateMaximumScale();

            return result.collision;
        };

        this.multiplyScale = function(delta_scale) {
            var next_scale = _scale * delta_scale,
                max_scale = _maximum_scale,
                next_pos,
                next_maximum_scale;

            if (next_scale > max_scale) {
                _scale = next_scale;
                next_pos = _calcNextPosition({x:_x, y:_y});
                next_maximum_scale = _calcNextMaximumScale(next_pos);

                if (Math.abs(next_maximum_scale - _maximum_scale) < 0.001) {
                    _scale = _maximum_scale;
                    return;
                }

                _x = next_pos.x;
                _y = next_pos.y;

                _maximum_scale = next_maximum_scale;

                next_scale = Math.min(next_scale, _maximum_scale);
            }

            _scale = Math.max(next_scale, 0.05);
        };

        this.resetShape = function(x, y, scale, degree, display_width, display_height) {
            _display_width = display_width;
            _display_height = display_height;
            _scale = scale;
            if (_display_width > _display_height) {
                _x = x;
                _y = y;
                _degree = degree;
            } else  {
                _x = 1.0 - x;
                _y = 1.0 - y;
                _degree = (degree + 180) % 360;
            }
            _maximum_scale = _calcMaximumScale();
        };

        this.resetShape(cx, cy, scale, degree, display_width, display_height);
    };

    CanvasState = function(canvas) {
        var _canvas = canvas,
            _ctx = _canvas.getContext('2d'),
            _valid = false, 
            _shape = null, 
            _dragging = false,
            _selection = null,
            _dragoffx = 0,
            _dragoffy = 0,
            _onchange = null,
            _active = false;

        function _onDragStart(x, y) {
            var mx = x,
                my = y;

            _dragoffx = mx - _shape.getX() * _canvas.width;
            _dragoffy = my - _shape.getY() * _canvas.height;
            _dragging = true;
            _selection = _shape;
            _valid = false;
        }

        function _onDrag(x,y) {
            if (_dragging){
                var collision = _selection.changePosition({
                    x:(x - _dragoffx) / _canvas.width,
                    y:(y - _dragoffy) / _canvas.height
                });

                if (collision.x !== null) {
                    _dragoffx = x - collision.x;
                }

                if (collision.y !== null) {
                    _dragoffy = y - collision.y;
                }

                _valid = false;
            }
        }

        function _onDragEnd() {
            _dragging = false;

            if (_onchange !== null) {
                _onchange();
            }
        }

        function _clear() {
            _ctx.clearRect(0, 0, _canvas.width, _canvas.height);
        }

        function _draw() {
            if (!_valid && _shape !== null) {
                _clear();
                _shape.draw(_ctx);
                _valid = true;
            }
        }

        function _compensateCanvasPosition() {
            if (window.innerHeight > 480) {
                _canvas.style.bottom = String(_canvas.height + 90) + 'px';
            } else  {
                _canvas.style.bottom = String(_canvas.height + 30) + 'px';
            }
        }

        this.clear = _clear;

        this.changeSize = function(width, height) {
            _canvas.width = width;
            _canvas.height = height;

            if (_canvas.width >= _canvas.height) {
                _canvas.style.borderBottomColor = 'rgba(160,160,160,0.77)';
                _canvas.style.borderRightColor = 'rgba(160,160,160,0.77)';
                _canvas.style.borderLeftColor = null;
            } else {
                _canvas.style.borderBottomColor = 'rgba(160,160,160,0.77)';
                _canvas.style.borderLeftColor = 'rgba(160,160,160,0.77)';
                _canvas.style.borderRightColor = null;
            }

            _compensateCanvasPosition();

            _valid = false;
        };

        this.setShape = function(shape) {
            _shape = shape;
            _valid = false;
        };

        this.onChange = function(f) {
            _onchange = f;
        };

        this.invalidate = function() {
            _valid = false;
        };

        this.activate = function() {
            if (_active) {
                return;
            }

            var rec_draw = function() { 
                if (_active) {
                    _draw(); 
                    global.displayLink(rec_draw);
                }
            };

            _active = true;

            global.displayLink(rec_draw);
        };

        this.deactivate = function() {
            _active = false;
        };

        _canvas.addEventListener('selectstart', function(e) { e.preventDefault(); return false; }, false);

        hybrid.onCoherentDrag(_canvas, _onDrag, _onDragStart, _onDragEnd);
    };


    global.ROIView = function() {
        this.container = document.getElementById('roi_view_container');

        var that = this,
            _canvas_state = new CanvasState(document.getElementById('roi_view')),
            _onchange_roi = null,
            _onchange_orientation = null,
            _display_width = null,
            _display_height = null,
            _capture_width = null,
            _capture_height = null,
            _buttons = {
                zoom_in: document.getElementById('zoom_in'),
                zoom_out: document.getElementById('zoom_out'),
                rotate: document.getElementById('rotate'),
                rotate_rev: document.getElementById('rotate_rev'),
                rotate_device: document.getElementById('rotate_device')
            },
            _roi_shape = null,
            _super_appear = this.appear,
            _super_disappear = this.disappear;

        function _calcROIInfo() {
            var ret = _roi_shape.getShape();        
            if (_display_width <= _display_height) {
                ret.x = 1.0 - ret.x;
                ret.y = 1.0 - ret.y;
                ret.degree = (ret.degree + 180) % 360;
            }

            return ret;
        }

        this.setROI = function(roi) {
            if (_roi_shape === null) {
                _roi_shape = new Shape(roi.x,
                                       roi.y,
                                       roi.scale,
                                       roi.degree,
                                       _display_width,
                                       _display_height);
            } else {
                _roi_shape.resetShape(roi.x,
                                      roi.y,
                                      roi.scale,
                                      roi.degree,
                                      _display_width,
                                      _display_height);
            }

            _canvas_state.setShape(_roi_shape);

            global.displayLink(function() {
                for (var label in _buttons) {
                    if (_buttons.hasOwnProperty(label)) {
                        hybrid.removeClass(_buttons[label], 'locked');
                        hybrid.removeClass(_buttons[label], 'pressed');
                    }
                }
            });
        };

        this.onChange = function(f) {
            _onchange_roi = f;
            _canvas_state.onChange(function() {
                f(_calcROIInfo());
            });
        };

        this.onChangeOrientation = function(f) {
            _onchange_orientation = f;
        };

        this.setDisplaySize = function(capture_width, capture_height) {
            var aspect_ratio = capture_height / capture_width,
                display_width, display_height;

            _capture_width = capture_width;
            _capture_height = capture_height;

            if (aspect_ratio < 1.0) {
                display_width = Math.min((window.innerHeight * 0.4) / aspect_ratio, window.innerWidth * 0.7);
                display_height = display_width * aspect_ratio;
            } else {
                display_height = window.innerHeight * 0.4; 
                display_width = display_height / aspect_ratio;
            }

            if (display_width !== _display_width ||
                display_height !== _display_height) {
                _display_width = display_width;
                _display_height = display_height;

                _canvas_state.clear();
                _canvas_state.changeSize(_display_width, _display_height);
            }
        };

        this.appear = function(on_end) {
            _canvas_state.activate();
            _super_appear.call(this, on_end);
        };

        this.disappear = function(on_end) {
            _canvas_state.deactivate();
            _super_disappear.call(this, on_end);
        };

        function _registerHoldable(elem, callbacks) {
            var _start_ms,
                _active = false,
                _callbacks = callbacks,
                HOLD_THRESHOLD_MS = 300;

            hybrid.onTap(elem, function() {
                if (hybrid.containsClass(elem, 'locked')) {
                    return;
                }
                _start_ms = (new Date()).getTime();
                _active = true;

                var rec_hold = function() {
                    if (_active) {
                        var delta_ms = (new Date()).getTime() - _start_ms;

                        if (delta_ms > HOLD_THRESHOLD_MS) {
                            _callbacks.on_hold(delta_ms);
                        }

                        global.displayLink(rec_hold);
                    }
                };

                global.displayLink(rec_hold);

            }, function() {
                _active = false;

                if (hybrid.containsClass(elem, 'locked')) {
                    return;
                }

                var delta_ms = (new Date()).getTime() - _start_ms;

                _callbacks.on_action();
                if (delta_ms <= HOLD_THRESHOLD_MS) {
                    _callbacks.on_click();
                } else {
                    _callbacks.on_hold_end();
                }

            });
        }

        function _registerROIHoldable(elem, callbacks) {
            var _callbacks = callbacks;
            _registerHoldable(elem, {
                on_hold: function(delta_ms) {
                    _callbacks.step_update(delta_ms);
                    _canvas_state.invalidate();
                }, 
                on_hold_end: function() {
                    if (_onchange_roi !== null) {
                        _onchange_roi(_calcROIInfo());
                    }
                },
                on_click: function() {
                    _callbacks.click_update();
                    _canvas_state.invalidate();
                    if (_onchange_roi !== null) {
                        _onchange_roi(_calcROIInfo());
                    }
                },
                on_action: function() {
                    hybrid.addClass(elem, 'pressed');
                    for (var label in _buttons) {
                        if (_buttons.hasOwnProperty(label)) {
                            hybrid.addClass(_buttons[label], 'locked');
                        }
                    }
                }
            });
        }

        function _decideDegreeStep(delta_ms) {
            var r = delta_ms / 3000.0;
            return Math.min(1.0, r * r);
        }

        function _decideScaleStep(delta_ms) {
            var r = delta_ms / 200000.0;
            return 1.0 + Math.min(0.01, r);
        }

        _registerROIHoldable(_buttons.rotate, {
            step_update: function(delta_ms) { _roi_shape.addDegree(_decideDegreeStep(delta_ms)); },
            click_update: function() { _roi_shape.addStepDegree(45); }
        });

        _registerROIHoldable(_buttons.rotate_rev, {
            step_update: function(delta_ms) { _roi_shape.addDegree(-_decideDegreeStep(delta_ms)); },
            click_update: function() { _roi_shape.addStepDegree(-45); }
        });

        _registerROIHoldable(_buttons.zoom_out, {
            step_update: function(delta_ms) { _roi_shape.multiplyScale(_decideScaleStep(delta_ms)); },
            click_update: function() { _roi_shape.multiplyScale(1.25); }
        });

        _registerROIHoldable(_buttons.zoom_in, {
            step_update: function(delta_ms) { _roi_shape.multiplyScale(1.0/_decideScaleStep(delta_ms)); },
            click_update: function() { _roi_shape.multiplyScale(1.0/1.25); }
        });

        hybrid.onTap(_buttons.rotate_device, function() {
            if (_onchange_orientation !== null) {
                _onchange_orientation();
            }
        });

        // FIXME: hacky
        try {
            hybrid.onWindowResize(function() {
                if (_capture_width !== null &&
                    _capture_height !== null) {
                    that.setDisplaySize(_capture_width, _capture_height);
                    _roi_shape.setDisplayWidth(_display_width);
                    _roi_shape.setDisplayHeight(_display_height);
                    _canvas_state.invalidate();
                }
            });
        } catch (e) {
            global.p(e);
        }
    };

    global.ROIView.prototype = new View();
}(this));
