(function(global) {
    var hybrid = global.hybrid,
        View = global.View,
        ConnectionEffect;

    ConnectionEffect = function() {
        this.container = document.getElementById('guard');
        this.indicator_node = document.getElementById('indicator');
    };

    ConnectionEffect.prototype = new View();

    ConnectionEffect.prototype.connecting = function() {
        this.appear();
        hybrid.removeClass(this.indicator_node, 'blink');
        hybrid.addClass(this.indicator_node, 'spinner');
    };

    ConnectionEffect.prototype.error = function() {
        this.appear();
        hybrid.removeClass(this.indicator_node, 'spinner');
        hybrid.addClass(this.indicator_node, 'blink');
    };

    global.ConnectionEffect = ConnectionEffect;
}(this));
