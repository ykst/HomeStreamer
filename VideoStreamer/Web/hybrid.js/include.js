(function(global) {
    global.include = function(list, on_end) {
        var load = function(path, continuation) {
                var js = document.createElement('script');
                js.type = 'text/javascript';
                js.src = path;

                js.onreadystatechange = continuation;
                js.onload = continuation;

                document.body.appendChild(js);
            },
            num_scripts = list.length,
            idx = 0,
            rec_load = function() {
                if (idx === num_scripts) {
                    on_end();
                    return;
                }

                load(list[idx], function() {
                    idx += 1;
                    rec_load();
                });
            };

        rec_load();
    };
}(this));
