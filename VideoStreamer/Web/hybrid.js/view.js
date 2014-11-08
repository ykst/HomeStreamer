(function(global) {
    var hybrid = global.hybrid,
        enable_class = 'enable',
        View;

    View = function() {
        this._enabled = null;
    };

    View.prototype.isEnabled = function() {
        if (this._enabled === null) {
            this._enabled = hybrid.containsClass(this.container, enable_class);
        }
        return this._enabled === true;
    };

    View.prototype.dismiss = function(on_end) {
        this._enabled = false;
        hybrid.dismiss(this.container);
        if (on_end !== global.__undefined) {
            on_end();
        }
    };

    View.prototype.disappear = function(on_end) {
        var that = this;
        this._enabled = false;

        hybrid.removeClass(this.container, enable_class);

        setTimeout(function() {
            if (!that._enabled) {
                that.dismiss();

                if (on_end !== global.__undefined) {
                    on_end();
                }
            }
        }, 300);
    };

    View.prototype.appear = function(on_end) {
        var that = this;
        this._enabled = true;
        hybrid.show(this.container);

        setTimeout(function() {
            if (that._enabled) {

                hybrid.addClass(that.container, enable_class);
                if (on_end !== global.__undefined) {
                    setTimeout(function() {
                        if (that._enabled) {
                            on_end();
                        }
                    }, 300);
                }
            }
        }, 50);
    };

    View.prototype.toggleAppear = function(on_end) {
        if (this._enabled === true) {
            this.disappear(on_end);
        } else {
            this.appear(on_end);
        }
    };

    View.elemToView = function(elem) {
        return new (function() {
            var obj = function() {
                this.container = elem;
            };

            obj.prototype = new View();

            return obj;
        }())();
    };

    View.setEnableClass = function(c) {
        enable_class = c;
    };

    global.View = View;
}(this));
