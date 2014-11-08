(function(global) {
    var Hybrid = function() {
        var that = this,
            _is_mobile = null;

        function _computedStyle(element, pseudo, style) {
            var css;
            if (document.defaultView && document.defaultView.getComputedStyle) {
                css = document.defaultView.getComputedStyle(element, pseudo);
                if (css !== null) {
                    return css[style];
                }
            }
        }

        function _ctxOffsetXY(ctx) {
            var element = ctx.element,
                html = document.body.parentNode,
                htmlTop = html.offsetTop,
                htmlLeft= html.offsetLeft,
                stylePaddingLeft,
                stylePaddingTop,
                styleBorderLeft,
                styleBorderTop;

            ctx.offsetX = 0;
            ctx.offsetY = 0;

            if (element.offsetParent !== undefined) {
                do {
                    ctx.offsetX += element.offsetLeft;
                    ctx.offsetY += element.offsetTop;
                    element = element.offsetParent;
                } while (element);
            }

            element = ctx.element;

            stylePaddingLeft = parseInt(_computedStyle(element, null, 'paddingLeft'), 10) || 0;
            stylePaddingTop  = parseInt(_computedStyle(element, null, 'paddingTop'), 10) || 0;
            styleBorderLeft  = parseInt(_computedStyle(element, null, 'borderLeftWidth'), 10) || 0;
            styleBorderTop   = parseInt(_computedStyle(element, null, 'borderTopWidth'), 10) || 0;

            ctx.offsetX += stylePaddingLeft + styleBorderLeft + htmlLeft;
            ctx.offsetY += stylePaddingTop + styleBorderTop + htmlTop;
        }

        function _ctxRelativeXY(ctx, pageX, pageY) {

            _ctxOffsetXY(ctx);

            var mx = pageX - ctx.offsetX,
                my = pageY - ctx.offsetY;

            return {x: mx, y: my};
        }

        this.onInnerTouchStart = function(element, f) {
            if ((typeof element) !== 'object' || (typeof element.addEventListener) !== 'function') {
                return;
            }

            var ctx = {element: element},
                cb = function(e) {
                    var pos = _ctxRelativeXY(ctx, e.pageX, e.pageY);
                    if (!that.containsClass(element, 'unavailable')) {
                        f(pos.x, pos.y);
                    }
                    return false;
                };

            if (document.documentElement.ontouchstart !== global.__undefined) {
                element.addEventListener('touchstart', cb, true);
            } else {
                element.addEventListener('mousedown', cb, true);
            }
        };

        this.onClick = function(element, f) {
            if ((typeof element) !== 'object' || (typeof element.addEventListener) !== 'function') {
                return;
            }
            var ctx = {element: element},
                cb = function(e) {
                    var pos = _ctxRelativeXY(ctx, e.pageX, e.pageY);
                    if (!that.containsClass(element, 'unavailable')) {
                        f(pos.x, pos.y);
                    }
                };

            element.addEventListener('click', cb, true);
        };

        this.onInnerTouchMove = function(element, f) {
            if ((typeof element) !== 'object' || (typeof element.addEventListener) !== 'function') {
                return;
            }
            var ctx = {element: element};

            if (document.documentElement.ontouchmove !== global.__undefined) {
                element.addEventListener('touchmove', function(e) {
                    var pos = _ctxRelativeXY(ctx, e.touches[0].pageX, e.touches[0].pageY);
                    if (!that.containsClass(element, 'unavailable')) {
                        f(pos.x, pos.y);
                    }
                }, true);
            } else {
                element.addEventListener('mousemove', function(e) {
                    var pos = _ctxRelativeXY(ctx, e.pageX, e.pageY);
                    if (!that.containsClass(element, 'unavailable')) {
                        f(pos.x, pos.y);
                    }
                }, true);
            }
        };

        this.onInnerMouseOver = this.onInnerTouchMove;

        this.onTouchEnd = function(element, f) {
            if (document.documentElement.ontouchend !== global.__undefined) {
                element.addEventListener('touchend', f, true);
                element.addEventListener('touchcancel', f, true);
            } else {
                element.addEventListener('mouseup', f, true);
            }
        };

        this.onCoherentDrag = function(element, drag_f, start_f, end_f) {
            var dragging = false,
                ctx = {element:element};

            that.onInnerTouchStart(element, function(x, y) {
                _ctxOffsetXY(ctx);
                if (start_f !== undefined && !dragging) {
                    if (!that.containsClass(element, 'unavailable')) {
                        start_f(x, y);
                    }
                }
                dragging = true;
            });

            that.onInnerTouchMove(document.body, function(x, y) {
                if (dragging) {
                    if (!that.containsClass(element, 'unavailable')) {
                        drag_f(x - ctx.offsetX, y - ctx.offsetY);
                    }
                }
            });

            that.onTouchEnd(window, function() {
                if (dragging) {
                    if (end_f !== global.__undefined) {
                        if (!that.containsClass(element, 'unavailable')) {
                            end_f();
                        }
                    }
                    dragging = false;
                }
            });
        };

        // nerver fired on mobile devices
        this.onHover = function(element, start_f, exit_f) {
            if (this.mobileCheck()) {
                return;
            }

            var hovering = false,
                ctx = {element:element};

            that.onInnerTouchMove(element, function(x, y) {
                if (!hovering) {
                    _ctxOffsetXY(ctx);

                    if (!that.containsClass(element, 'unavailable')) {
                        start_f(x, y);
                    }

                    hovering = true;
                }
            });

            that.onInnerTouchMove(document.body, function(x, y) {
                if (hovering) {
                    var pos = that.calcNormalizedPos(element, x - ctx.offsetX, y - ctx.offsetY);
                    if (pos.x < 0 || pos.x > 1 ||
                        pos.y < 0 || pos.y > 1) {
                        hovering = false;
                        if (exit_f !== global.__undefined) {
                            if (!that.containsClass(element, 'unavailable')) {
                                exit_f();
                            }
                        }
                    }
                }
            });
        };

        this.onTap = function(element, start_f, end_f) {
            var tapping = false,
                ctx = {element:element};

            that.onInnerTouchStart(element, function(x, y) {
                _ctxOffsetXY(ctx);
                if (start_f !== undefined && !tapping) {
                    if (!that.containsClass(element, 'unavailable')) {
                        start_f(x, y);
                    }
                }
                tapping = true;
            });

            that.onTouchEnd(window, function() {
                if (tapping) {
                    if (end_f !== global.__undefined) {
                        if (!that.containsClass(element, 'unavailable')) {
                            end_f();
                        }
                    }
                    tapping = false;
                }
            });
        };

        this.calcNormalizedPos = function(element, x, y) {
            return {x: x / element.offsetWidth, 
                    y: y / element.offsetHeight};
        };

        this.calcElementOffset = function(from_element, to_element) {
            var from_ctx = {element:from_element},
                to_ctx = {element:to_element};
            _ctxOffsetXY(from_ctx);
            _ctxOffsetXY(to_ctx);
            return {x: to_ctx.offsetX - from_ctx.offsetX,
                    y: to_ctx.offsetY - from_ctx.offsetY};
        };

        this.clamp = function(v, min, max) {
            if (min === global.__undefined) { min = 0.0; }
            if (max === global.__undefined) { max = 1.0; }
            return Math.min(max, Math.max(min, v));
        };

        this.iterateChildren = function(element, f) {
            var i, child;
            for (i = 0; i < element.childNodes.length; ++i) {
                child = element.childNodes[i];
                if (f(child) === false) {
                    return false;
                }

                if (that.iterateChildren(child, f) === false) {
                    return false;
                }
            }

            return global.__undefined;
        };

        this.getChildOfClass = function(element, class_name) {
            var result;

            that.iterateChildren(element, function(c) {
                if (c.classList !== global.__undefined &&
                    c.classList.contains(class_name)) {
                    result = c;
                    return false;
                }
            });

            return result;
        };

        this.dismiss = function(element) {
            if (element.__parent_node === global.__undefined) {
                element.__parent_node = element.parentNode;
            }
            that.addClass(element, 'hide');
            if (element.__parent_node !== global.__undefined && 
                element.__parent_node !== null &&
                ((element.compareDocumentPosition(element.__parent_node) & Node.DOCUMENT_POSITION_CONTAINS) !== 0)) {
                element.__parent_node.removeChild(element);
            }
        };

        this.unused = function(element) {
            that.addClass(element, 'unused');
            that.removeClass(element, 'used');
        };

        this.show = function(element) {
            that.removeClass(element, 'hide');
            if (element.__parent_node !== global.__undefined && 
                element.__parent_node !== null) {
                element.__parent_node.appendChild(element);
            }
        };

        this.addClass = function(element, class_name) {
            if (!element.classList.contains(class_name)) {
                element.classList.add(class_name);
            }
        };

        this.removeClass = function(element, class_name) {
            if (element.classList.contains(class_name)) {
                element.classList.remove(class_name);
            }
        };

        this.containsClass = function(element, class_name) {
            return element.classList !== global.__undefined && element.classList.contains(class_name);
        };

        this.toggleClass = function(element, class_name) {
            element.classList.toggle(class_name);
        };

        this.getChildOfID = function(element, id) {
            var result;

            that.iterateChildren(element, function(c) {
                if (c.id !== global.__undefined &&
                    c.id === id) {
                    result = c;
                    return false;
                }
            });

            return result;
        };

        this.registerDisplayLink = function() {
            var displayLink = window.requestAnimationFrame ||
                window.webkitRequestAnimationFrame ||
                window.mozRequestAnimationFrame ||
                function(callback){
                    setTimeout(callback, 1000 / 60);
                };

            global.displayLink = function(){
                displayLink.apply(window, arguments);
            };
        };

        this.onWindowResize = function(f) {
            window.addEventListener('resize', function() {
                f();
            });
        };

        this.allYourMouseEventAreBelongToUs = function(stylesheet_directory) {
            if (stylesheet_directory === global.__undefined) {
                stylesheet_directory = '';
            }

            try {
                document.ontouchmove = function(event) {
                    event.preventDefault();
                };
                document.onmousedown = function(event) {
                    if (event.target.tagName !== "INPUT") {
                        event.preventDefault(); 
                    }
                };
                that.onWindowResize(function() {
                    // iOS 7.1 Safari minimal-ui fix
                    setTimeout(function() {
                        window.scrollTo(0,1);
                    }, 0);
                });
            } catch(ignore) {
                // well.. 
            }
        };

        this.mobileCheck = function() {
            if (_is_mobile === null) {
                _is_mobile = (document.documentElement.ontouchstart !== global.__undefined);
            }
            return _is_mobile;
        };
    };

    global.hybrid = new Hybrid();
}(this));
