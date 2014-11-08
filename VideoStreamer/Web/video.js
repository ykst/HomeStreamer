(function(global) {
    var @debug(p = global.p,)
        MediaStream = global.MediaStream,
        MAXIMUM_BUFFERING_FRAMES = 300, // approx. 10sec
        DiffJPEG,
        IMG_STOCK_SIZE = 60,
        _latest_object_url = null,
        _img_stock_idx = 0,
        _img_stocks = new Array(IMG_STOCK_SIZE); 

    // dynamic allocation of Image() with canvas.drawImage() may 
    // result in severe memory leak on some bleeding edge browsers
    for (var i = 0; i < IMG_STOCK_SIZE; ++i) {
        _img_stocks[i] = new Image();
    }

    function _getImageStock() {
        var img = _img_stocks[_img_stock_idx];
        _img_stock_idx = (_img_stock_idx + 1) % IMG_STOCK_SIZE;
        return img;
    }

    DiffJPEG = function(width, height, output_canvas) {
        var _width = width,
            _height = height,
            _output_canvas_ctx = output_canvas.getContext('2d'),
            _wasted = false;

        window.URL = window.URL || window.webkitURL;

        function _revokeObjectURL(url) {
            if (_latest_object_url !== null) {
                window.URL.revokeObjectURL(_latest_object_url);
            }

            _latest_object_url = url;
        }

        function _createJPEGObjectURL(buf) {
            return window.URL.createObjectURL(new Blob([buf], {type:'image/jpeg'}));
        }

        function _loadImage(buf, onload) {
            var img = _getImageStock();

            img.src = _createJPEGObjectURL(buf);

            img.onload = function() { 
                if (img.width === _width &&
                    img.height === _height &&
                    _wasted !== true) {
                    onload(img);  // must use img immediately
                }

                _revokeObjectURL(img.src);
            };

            img.onerror = function(@debug(e)) {
                @log('img.onerror')
                @log(e)
                _revokeObjectURL(img.src);
            };
        }

        this.youWasted = function() {
            _wasted = true;
        };

        this.isSameSize = function(width, height) {
            return _width === width && _height === height;
        };

        this.feedIFrame = function(ibuf, continuation) {
            (function() {
                var draw_ibuf = ibuf;
                continuation(function() {
                    _loadImage(draw_ibuf, function(img) {
                        if (_width === img.width &&
                            _height === img.height &&
                            _wasted !== true) {
                            _output_canvas_ctx.drawImage(img, 0,0);
                        }
                    });
                });
            }());
        };
    };

    global.VideoPlayer = function(output_canvas, audio_timer) {
        var _task_queue = [],
            _diffjpeg = null,
            _frame_updated = false,
            _audio_timer = audio_timer,
            _output_canvas = output_canvas;

        function _scheduleTask(scheduling_task) {
            if (scheduling_task !== global.__undefined) {
                _task_queue.unshift(scheduling_task);
            }

            global.displayLink(function() {
                var task = _task_queue.pop(),
                    num_pending_tasks,
                    audio_sync_time,
                    last_task,
                    dispose_tasks;

                if (task === global.__undefined) {
                    @log('no task')
                    return;
                }

                num_pending_tasks = _task_queue.length;

                if (num_pending_tasks >= MAXIMUM_BUFFERING_FRAMES) {
                    @log('too many buffers!')
                    _task_queue = [];
                    return;
                }

                audio_sync_time = _audio_timer.getAudioSyncTime();

                if (audio_sync_time > 0) {
                    if (audio_sync_time < task.video_sync_time) {
                        @log('delaying video..')
                        _task_queue.push(task);
                        _scheduleTask();
                        return;
                    }

                    last_task = _task_queue.slice(-1)[0];
                    dispose_tasks = [];

                    while (last_task !== global.__undefined) {
                        if (audio_sync_time < last_task.video_sync_time) {
                            break;
                        }
                        dispose_tasks.push(_task_queue.pop());
                        last_task = _task_queue.slice(-1)[0];
                    }

                    if (dispose_tasks.length > 0) {
                        @log('fastforwarded tasks: ' + dispose_tasks.length)
                        // select middle frame to reduce skipping artifact
                       task = dispose_tasks[Math.floor(dispose_tasks.length / 2)];
                    }
                } 

                task();

                _frame_updated = true;
            });
        }

        this.setDisplay = function(width, height) {
            if (_diffjpeg === null ||
                !_diffjpeg.isSameSize(width, height)) {

                if (_diffjpeg !== null) {
                    _diffjpeg.youWasted();
                }

                _output_canvas.width = width;
                _output_canvas.height = height;

                _diffjpeg = new DiffJPEG(width, height, _output_canvas);
            }
        };

        this.getLatestObjectURL = function() {
            return _latest_object_url;
        };

        this.pollFrameUpdate = function() {
            var ret = _frame_updated;

            _frame_updated = false;

            return ret;
        };

        this.scheduleVideo = function(media_message) {
            if (media_message.category !== MediaStream.CATEGORY) {
                @throw("internal inconsistency")
            }

            if (media_message.type !== MediaStream.TYPE_VIDEO_JPG) {
                @throw('unsupported MediaStream: ' + media_message.type)
            }

            (function() {
                var video_sync_time = media_message.timestamp_sec + media_message.timestamp_usec / 1e6;
                
                _diffjpeg.feedIFrame(media_message.getUint8Payload(0), function(do_task) {
                    do_task.video_sync_time = video_sync_time;
                    _scheduleTask(do_task);
                });
            }());
        };
    };
}(this));
