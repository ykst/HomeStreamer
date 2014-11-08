(function(global) {
    var jsSHA = global.jsSHA,
        /*jshint ignore:start*/
        HEADER_MAGIC_BYTES_1 = parseInt('$_$MESSAGE_MAGIC_BYTES_1$_$', 10),
        HEADER_MAGIC_BYTES_2 = parseInt('$_$MESSAGE_MAGIC_BYTES_2$_$', 10),
        HEADER_MAGIC_BYTES_3 = parseInt('$_$MESSAGE_MAGIC_BYTES_3$_$', 10),
        HEADER_MAGIC_BYTES_4 = parseInt('$_$MESSAGE_MAGIC_BYTES_4$_$', 10),
        HEADER_MAGIC_BYTES = [HEADER_MAGIC_BYTES_1, HEADER_MAGIC_BYTES_2, HEADER_MAGIC_BYTES_3, HEADER_MAGIC_BYTES_4],
        HEADER_VERSION = parseInt('$_$MESSAGE_VERSION$_$', 10), // jshint ignore:line
        HEADER_LENGTH = parseInt('$_$MESSAGE_HEADER_LENGTH$_$', 10), // jshint ignore:line
        SWS_PASSWORD_BRIDGE_STR = '$_$SWS_PASSWORD_BRIDGE_STR$_$',
        /*jshint ignore:end*/
        Message,
        SWSControlMessage;

    Message = function(array_buf) {
        this.array_buf = array_buf;

        var view = new DataView(array_buf);

        if (!(view.getUint8(0) === HEADER_MAGIC_BYTES[0] &&
              view.getUint8(1) === HEADER_MAGIC_BYTES[1] &&
              view.getUint8(2) === HEADER_MAGIC_BYTES[2] &&
              view.getUint8(3) === HEADER_MAGIC_BYTES[3])) {
            @throw('invalid magic bytes')
        }

        if (view.getUint32(4, false) !== array_buf.byteLength) {
            @throw('length mismatch')
        }

        if (view.getUint16(8, false) !== HEADER_VERSION) {
            @throw('header version mismatch')
        }

        this.category = view.getUint8(10);
        this.type = view.getUint8(11);
        this.timestamp_sec = view.getUint32(12, false);
        this.timestamp_usec = view.getUint32(16, false);

        this.payload_length = this.array_buf.byteLength - HEADER_LENGTH;
    };

    Message.HEADER_LENGTH = HEADER_LENGTH;

    Message.prototype.getFloat32Payload = function(offset) {
        if (offset === global.__undefined) {
            offset = 0;
        }
        return new Float32Array(this.array_buf, HEADER_LENGTH + offset);
    };

    Message.prototype.getUint8Payload = function(offset) {
        if (offset === global.__undefined) {
            offset = 0;
        }
        return new Uint8Array(this.array_buf, HEADER_LENGTH + offset);
    };

    Message.prototype.getViewOfPayload = function(offset) {
        if (offset === global.__undefined) {
            offset = 0;
        }
        return new DataView(this.array_buf, HEADER_LENGTH + offset);
    };

    Message.setHeader = function(category, type, view) {
        var i, date;

        for (i = 0; i < 4; ++i) {
            view.setUint8(i, HEADER_MAGIC_BYTES[i]);
        }

        view.setUint32(4, view.byteLength & 0xFFFFFFFF, false);

        view.setUint8(8, (HEADER_VERSION >> 8) & 0xFF);
        view.setUint8(9, (HEADER_VERSION >> 0) & 0xFF);

        view.setUint8(10, category & 0xFF);
        view.setUint8(11, type & 0xFF);

        date = new Date();
        view.setUint32(12, Math.round(date.getTime() / 1000), false);
        view.setUint32(16, date.getUTCMilliseconds() * 1000, false);
    };


    SWSControlMessage = function() {
        return;
    };

    SWSControlMessage.CATEGORY = parseInt('$_$MESSAGE_CATEGORY_SWS_CTRL$_$', 10);
    SWSControlMessage.SWS_CTRL_BIL_HELLO = parseInt('$_$SWS_CTRL_BIL_HELLO$_$', 10);
    SWSControlMessage.SWS_CTRL_S2C_PASSWORD_REQUIRED = parseInt('$_$SWS_CTRL_S2C_PASSWORD_REQUIRED$_$', 10);
    SWSControlMessage.SWS_CTRL_C2S_PASSWORD = parseInt('$_$SWS_CTRL_C2S_PASSWORD$_$', 10);
    SWSControlMessage.SWS_CTRL_C2S_WAITING_INPUT = parseInt('$_$SWS_CTRL_C2S_WAITING_INPUT$_$', 10);
    SWSControlMessage.SWS_CTRL_S2C_WAITING_INPUT = parseInt('$_$SWS_CTRL_S2C_WAITING_INPUT$_$', 10);
    SWSControlMessage.SWS_CTRL_S2C_RESET = parseInt('$_$SWS_CTRL_S2C_RESET$_$', 10);

    SWSControlMessage.prototype._makePacket = function(type, payload_array_buf) {
        var payload_length = (payload_array_buf === global.__undefined) ? 0 : payload_array_buf.byteLength,
            message_u8 = new Uint8Array(HEADER_LENGTH + payload_length),
            payload_dst_u8,
            payload_src_u8;

        Message.setHeader(SWSControlMessage.CATEGORY, type, new DataView(message_u8.buffer));

        if (payload_length > 0) {
            payload_dst_u8 = new Uint8Array(message_u8.buffer, HEADER_LENGTH);
            payload_src_u8 = new Uint8Array(payload_array_buf);

            payload_dst_u8.set(payload_src_u8);
        }

        return message_u8.buffer;
    };

    SWSControlMessage.prototype.hello = function() {
        return this._makePacket(SWSControlMessage.SWS_CTRL_BIL_HELLO);
    };

    SWSControlMessage.prototype.waitingInput = function() {
        return this._makePacket(SWSControlMessage.SWS_CTRL_C2S_WAITING_INPUT);
    };

    SWSControlMessage.prototype.password = function(plain_text, seed) {
        var payload_view = new Uint8Array(20),
            hex_str = 
                (new jsSHA((new jsSHA(plain_text,'ASCII')).getHash('SHA-1','HEX') + SWS_PASSWORD_BRIDGE_STR + seed,'ASCII')).getHash('SHA-1','HEX'),
            i;

        for (i = 0; i < 20; ++i) {
            payload_view[i] = parseInt('0x' + hex_str.substr(i * 2, 2), 16);
        }

        return this._makePacket(SWSControlMessage.SWS_CTRL_C2S_PASSWORD, payload_view.buffer);
    };

    SWSControlMessage.readOctetStatus = function(message, reader_func) {
        var view = message.getViewOfPayload(),
            stat = view.getUint8(0);

        reader_func(stat);
    };

    SWSControlMessage.readPasswordSeed = function(message, reader_func) {
        var buf_u8 = message.getUint8Payload();
        reader_func(String.fromCharCode.apply(null, buf_u8));
    };

    global.Message = Message;
    global.SWSControlMessage = SWSControlMessage;
}(this));
