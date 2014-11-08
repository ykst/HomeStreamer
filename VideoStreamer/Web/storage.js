(function(global) {
    var Storage = function() {
        var _has_local_storage = null,
            api_key = 'localStorage'; // for jshint

        // TODO: should refactor out
        function _hasLocalStorage() {
            if (_has_local_storage !== null) { return _has_local_storage; }

            var ret;

            try {
                ret = (api_key in window) && (window[api_key] !== null);
            } catch (e) {
                ret = false;
            }

            _has_local_storage = ret;

            return ret;
        }

        this.isSupported = function() {
            return _hasLocalStorage();
        };

        this.get = function(key) {
            if (!_hasLocalStorage()) { return null; }

            var ret;

            try {
                ret = window[api_key][key];
            } catch(e) {
                return null;
            }

            if (ret === global.__undefined) {
                ret = null;
            }

            return ret;
        };

        this.set = function(key, value) {
            if (!_hasLocalStorage()) { return false; }

            try {
                window[api_key][key] = value;
            } catch(e) {
                return false;
            }

            return true;
        };
    };

    global.storage = new Storage();
}(this));
