## Home Streamer - streaming video/audio

This is the full source code of [Home Streamer](https://itunes.apple.com/app/home-streamer-streaming-video/id862915269?mt=8) on the AppStore.

The code is basically identical to version 1.2.0 except some post-processing optimizations.

### Build Instruction
 
**Heads up! We use submodules.** Please clone this repository with --recursive option.

Beware simulators are not supported. It only works on actual devices.

 1. clone
 ```
$ git clone --recursive https://github.com/ykst/HomeStreamer
```
 2. resolve [Cocoapods](http://cocoapods.org/) dependencies
 ```
$ pod install
```
 3. open `VideoStreamer.xcworkspace` with Xcode and build it
 4. compile and install front-end codes
 ```
$ cd VideoStreamer/Web && make install
```
 5. install the built app into iDevices by Xcode

### Technical Features

 * Pure html5 MJPEG/IMA4 realtime multimedia streaming.
 * Plugin-free frontend written by plain css3/javascript.
 * App remote control via Websockets.
 * OpenGL ES2 accelarated image processing.
 * Multithreaded pipeline.
 * UPnP port forwarding for the external network access.

### Requirements

 iOS6.0 or later (Universal). 
 Note that arm64 is not included in standard architectures,
 so you would need to select Release mode to run on recent 64bit devices.

### Online Helps

 * English: http://www.monadworks.com/products/home-streamer/support/
 * Japanese: http://www.monadworks.com/products/home-streamer/support/ja/

### Redistributed Third-party Codes

 * [libjpeg-turbo](http://www.libjpeg-turbo.org/)
 * [CocoaHTTPServer](https://github.com/robbiehanson/CocoaHTTPServer/)
 * [MiniUPnP](http://miniupnp.free.fr/)
 * [jsSHA](http://caligatio.github.io/jsSHA/)

### Acknowledgements

 * [Question Mark designed by Cris Dobbins from the Noun Project](http://thenounproject.com/term/question-mark/33699/)
 * [Brightness designed by John Caserta from the Noun Project](http://thenounproject.com/term/brightness/36910/)
 * [Grid designed by Andrew Lynne from the Noun Project](http://thenounproject.com/term/grid/26606/)
 * Grid designed by Michael Rowe from the Noun Project [1](http://thenounproject.com/term/grid/18045/) [2](http://thenounproject.com/term/grid/18046/)
 * Volume designed by Dmitry Baranovskiy from the Noun Project [1](http://thenounproject.com/term/volume/5053/) [2](http://thenounproject.com/term/volume/5054/) [3](http://thenounproject.com/term/volume/5055/) [4](http://thenounproject.com/term/volume/5056/)
 * [Information designed by David Cadusseau from the Noun Project](http://thenounproject.com/term/information/5745/)
 * [Wifi designed by Housin Aziz from the Noun Project](http://thenounproject.com/term/wifi/38079/)
 * Rotate designed by Cornelius Danger from the Noun Project [1](http://thenounproject.com/term/rotate/26870/) [2](http://thenounproject.com/term/rotate/26867/)
 * Zoom and Zoom Out designed by Michael Zenaty from the Noun Project [1](http://thenounproject.com/term/zoom/11806/) [2](http://thenounproject.com/term/zoom-out/11807/)
 * [Rotate Ipad designed by Josh Deane from the Noun Project](http://thenounproject.com/term/rotate-ipad/20386/)
 * [Camera designed by Edward Boatman from the Noun Project](http://thenounproject.com/term/camera/476/)
 * [Wifi Icon made by Freepik.com](http://www.flaticon.com/free-icon/pins-maps-wifi_8152)
 * [Default Icon by interactivemania](http://www.defaulticon.com/)

### Author

ykst at monadworks https://github.com/ykst

### License

BSD-3
