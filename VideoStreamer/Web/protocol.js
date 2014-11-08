(function(global) {
    var Message = global.Message,
        ControlMessageFactory,
        MediaStream,
        ControlMessage;

    ControlMessageFactory = function() {
        return;
    };

    /*jshint ignore:start*/
    ControlMessageFactory.CATEGORY = parseInt('$_$MESSAGE_CATEGORY_CTRL$_$', 10);
    ControlMessageFactory.CTRL_C2S_QUERY_SPEC = parseInt('$_$CTRL_C2S_QUERY_SPEC$_$', 10);
    ControlMessageFactory.CTRL_S2C_SHOW_SPEC = parseInt('$_$CTRL_S2C_SHOW_SPEC$_$', 10);
    ControlMessageFactory.CTRL_C2S_REQUEST_IFRAME = parseInt('$_$CTRL_C2S_REQUEST_IFRAME$_$', 10);
    ControlMessageFactory.CTRL_C2S_START_STREAMING = parseInt('$_$CTRL_C2S_START_STREAMING$_$', 10);
    ControlMessageFactory.CTRL_C2S_SET_ROI = parseInt('$_$CTRL_C2S_SET_ROI$_$', 10);
    ControlMessageFactory.CTRL_C2S_SET_LEVELS = parseInt('$_$CTRL_C2S_SET_LEVELS$_$', 10);
    ControlMessageFactory.CTRL_S2C_VIDEO_DISABLED = parseInt('$_$CTRL_S2C_VIDEO_DISABLED$_$', 10);
    ControlMessageFactory.CTRL_C2S_AUDIO_ENABLED = parseInt('$_$CTRL_C2S_AUDIO_ENABLED$_$', 10);
    ControlMessageFactory.CTRL_C2S_AUDIO_DISABLED = parseInt('$_$CTRL_C2S_AUDIO_DISABLED$_$', 10);
    ControlMessageFactory.CTRL_S2C_AUDIO_USE = parseInt('$_$CTRL_S2C_AUDIO_USE$_$', 10);
    ControlMessageFactory.CTRL_S2C_AUDIO_UNUSE = parseInt('$_$CTRL_S2C_AUDIO_UNUSE$_$', 10);
    ControlMessageFactory.CTRL_C2S_LIGHT_CONTROL = parseInt('$_$CTRL_C2S_LIGHT_CONTROL$_$', 10);
    ControlMessageFactory.CTRL_S2C_LIGHT_STATUS = parseInt('$_$CTRL_S2C_LIGHT_STATUS$_$', 10);
    ControlMessageFactory.CTRL_C2S_FOCUS_CONTROL = parseInt('$_$CTRL_C2S_FOCUS_CONTROL$_$', 10);
    ControlMessageFactory.CTRL_S2C_FOCUS_STATUS = parseInt('$_$CTRL_S2C_FOCUS_STATUS$_$', 10);
    ControlMessageFactory.CTRL_C2S_CHANGE_ORIENTATION= parseInt('$_$CTRL_C2S_CHANGE_ORIENTATION$_$', 10);
    ControlMessageFactory.CTRL_C2S_REPORT = parseInt('$_$CTRL_C2S_REPORT$_$', 10);
    ControlMessageFactory.CTRL_S2C_REPORT = parseInt('$_$CTRL_S2C_REPORT$_$', 10);
    /*jshint ignore:end*/

    ControlMessageFactory.prototype._makePacket = function(type, payload_array_buf) {
        var payload_length = (payload_array_buf === global.__undefined) ? 0 : payload_array_buf.byteLength,
            message_u8 = new Uint8Array(Message.HEADER_LENGTH + payload_length),
            payload_dst_u8,
            payload_src_u8;

        Message.setHeader(ControlMessageFactory.CATEGORY, type, new DataView(message_u8.buffer));

        if (payload_length > 0) {
            payload_dst_u8 = new Uint8Array(message_u8.buffer, Message.HEADER_LENGTH);
            payload_src_u8 = new Uint8Array(payload_array_buf);

            payload_dst_u8.set(payload_src_u8);
        }

        return message_u8.buffer;
    };

    ControlMessageFactory.prototype.focusControl = function(on) {
        var payload_view = new Uint8Array(1);

        if (on) {
            payload_view[0] = 1;
        } else {
            payload_view[0] = 0;
        }

        return this._makePacket(ControlMessageFactory.CTRL_C2S_FOCUS_CONTROL, payload_view.buffer);
    };

    ControlMessageFactory.prototype.lightControl = function(on) {
        var payload_view = new Uint8Array(1);

        if (on) {
            payload_view[0] = 1;
        } else {
            payload_view[0] = 0;
        }

        return this._makePacket(ControlMessageFactory.CTRL_C2S_LIGHT_CONTROL, payload_view.buffer);
    };

    ControlMessageFactory.prototype.requestIFrame = function() {
        return this._makePacket(ControlMessageFactory.CTRL_C2S_REQUEST_IFRAME);
    };

    ControlMessageFactory.prototype.changeOrientation = function() {
        return this._makePacket(ControlMessageFactory.CTRL_C2S_CHANGE_ORIENTATION);
    };

    ControlMessageFactory.prototype.report = function(processed_frames,
                                                     video_received_times,
                                                     audio_discontinued_count,
                                                     audio_redundant_buffer_count) {
        var payload_view = new DataView(new Uint8Array(16).buffer);

        payload_view.setUint32(0, processed_frames, false);
        payload_view.setUint32(4, video_received_times, false);
        payload_view.setUint32(8, audio_discontinued_count, false);
        payload_view.setUint32(12, audio_redundant_buffer_count, false);

        return this._makePacket(ControlMessageFactory.CTRL_C2S_REPORT, payload_view.buffer);
    };

    ControlMessageFactory.prototype.setROI = function(roi) {
        var payload_view = new DataView(new Uint8Array(8).buffer),
            x_u16 = Math.floor(roi.x * 65535.0),
            y_u16 = Math.floor(roi.y * 65535.0),
            scale_u16 = Math.floor(roi.scale * 65535.0);

        payload_view.setUint16(0, x_u16, false);
        payload_view.setUint16(2, y_u16, false);
        payload_view.setUint16(4, scale_u16, false);
        payload_view.setUint16(6, roi.degree, false);

        return this._makePacket(ControlMessageFactory.CTRL_C2S_SET_ROI, payload_view.buffer);
    };

    ControlMessageFactory.prototype.setLevels = function(levels) {
        var payload_view = new DataView(new Uint8Array(4).buffer);

        payload_view.setUint8(0, levels.video_quality);
        payload_view.setUint8(1, levels.sound_buffering);
        payload_view.setUint8(2, levels.contrast_adjustment);

        return this._makePacket(ControlMessageFactory.CTRL_C2S_SET_LEVELS, payload_view.buffer);
    };

    ControlMessageFactory.prototype.startStreaming = function() {
        return this._makePacket(ControlMessageFactory.CTRL_C2S_START_STREAMING);
    };

    ControlMessageFactory.prototype.audioControl = function(is_enabled) {
        return this._makePacket(is_enabled ? ControlMessageFactory.CTRL_C2S_AUDIO_ENABLED : ControlMessageFactory.CTRL_C2S_AUDIO_DISABLED);
    };

    ControlMessageFactory.prototype.querySpec = function() {
        return this._makePacket(ControlMessageFactory.CTRL_C2S_QUERY_SPEC);
    };

    MediaStream = {};
    /*jshint ignore:start*/
    MediaStream.CATEGORY = parseInt('$_$MESSAGE_CATEGORY_MEDIA_STREAM$_$', 10);
    MediaStream.TYPE_VIDEO_JPG = parseInt('$_$MEDIA_STREAM_VIDEO_JPG$_$', 10);
    MediaStream.TYPE_VIDEO_DIFFJPG = parseInt('$_$MEDIA_STREAM_VIDEO_DIFFJPG$_$', 10);
    MediaStream.TYPE_AUDIO_PCM = parseInt('$_$MEDIA_STREAM_AUDIO_PCM$_$', 10);
    MediaStream.TYPE_AUDIO_ADPCM = parseInt('$_$MEDIA_STREAM_AUDIO_ADPCM$_$', 10);
    MediaStream.TYPE_VIDEO_JSMPEG = parseInt('$_$MEDIA_STREAM_VIDEO_JSMPEG$_$', 10);
    MediaStream.TYPE_SPEC = parseInt('$_$MEDIA_STREAM_SPEC$_$', 10);
    /*jshint ignore:end*/

    ControlMessage = function(message) {
        if (message.category !== ControlMessageFactory.CATEGORY) {
            @throw("category mismatch")
        }
        this.message = message;
    };

    ControlMessage.prototype.readSetting = function(reader_func) {
        if (this.message.type !== ControlMessageFactory.CTRL_S2C_SHOW_SPEC) {
            @throw("payload type mismatch")
        }

        var view = this.message.getViewOfPayload(),
            ret = {},
            base = 0;
        ret.screen_width = view.getUint16(base, false);
        ret.screen_height = view.getUint16(base + 2, false);
        base += 4;

        ret.capture_width = view.getUint16(base, false);
        ret.capture_height = view.getUint16(base + 2, false);
        base += 4;

        ret.quality = view.getUint8(base, false);
        ret.resolution_level = view.getUint8(base + 1, false);
        ret.sound_buffering_level = view.getUint8(base + 2, false);
        ret.contrast_adjustment_level = view.getUint8(base + 3, false);
        base += 4;

        ret.roi = {};

        ret.roi.x = view.getUint16(base, false) / 65535.0;
        ret.roi.y = view.getUint16(base + 2, false) / 65535.0;
        base += 4;

        ret.roi.scale = view.getUint16(base, false) / 65535.0;
        ret.roi.degree = view.getUint16(base + 2, false);

        reader_func(ret);
    };

    ControlMessage.prototype.readOctetStatus = function(reader_func) {
        var view = this.message.getViewOfPayload(),
            stat = view.getUint8(0);

        reader_func(stat);
    };

    global.ControlMessageFactory = ControlMessageFactory;
    global.ControlMessage = ControlMessage;
    global.MediaStream = MediaStream;
}(this));
