(function(global) {
    (function() {
        @include(hybrid.js/hybrid.js)
        @include(hybrid.js/view.js)
        /*jshint ignore:start*/
        @include(../../ext/SimpleWebsocketServer.git/src/sha1.js)
        /*jshint ignore:end*/
        @include(../../ext/SimpleWebsocketServer.git/src/websocket.js)
        @include(../../ext/SimpleWebsocketServer.git/src/protocol.js)
        @include(../../ext/SimpleWebsocketServer.git/src/state.js)
        @include(storage.js)
        @include(setting.js)
        @include(roi.js)
        @include(protocol.js)
        @include(video.js)
        @include(sound.js)
        @include(effect.js)
        @include(state.js)
        @include(scene.js)
    }).apply(global);

    global.hybrid.registerDisplayLink();
    global.hybrid.allYourMouseEventAreBelongToUs();

    var audio_player = new global.AudioPlayer(new global.VolumeControl(document.getElementById('sound_control'))),
        audio_timer = audio_player.getAudioTimer(),
        video_player = new global.VideoPlayer(document.getElementById('screen'), audio_timer),
        scene_manager = new global.SceneManager(),
        connection = new global.WebSocketConnection("$_$WEBSOCKET_URL$_$", "$_$HEALTHCHECK_URL$_$"),
        state = new global.ClientStateMachine(video_player, audio_player, scene_manager, connection);

    state.run();
}({
    //p: function(e) { window.console.log(e); }
    p: function() { return; }
}));
