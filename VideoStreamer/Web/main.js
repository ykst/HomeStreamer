window.p = function(e) { console.log(e); };

(function (list, on_end) {
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

})(['hybrid.js/hybrid.js',
    'hybrid.js/websocket.js',
    'hybrid.js/view.js',
    'sha1.js',
    'setting.js',
    'roi.js',
    'protocol.js',
    'video.js',
    'sound.js',
    'effect.js',
    'state.js',
    'scene.js'], function() {

    var global = this;

    global.hybrid.registerDisplayLink();
    global.hybrid.allYourMouseEventAreBelongToUs();

    var audio_player = new AudioPlayer(new VolumeControl(document.getElementById('sound_control'))),
        audio_timer = audio_player.getAudioTimer(),
        video_player = new VideoPlayer(document.getElementById('screen'), audio_timer),
        scene_manager = new SceneManager(),
        connection = new WebSocketConnection("$_$WEBSOCKET_URL$_$"),
        state = new ClientStateMachine(video_player, audio_player, scene_manager, connection);

    state.run();
});
