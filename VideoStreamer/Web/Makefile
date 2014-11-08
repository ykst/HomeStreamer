INSTALL_DIR=../Assets/Web
TARGET=index.html
TMPL_HTML=index-tmpl.html
BODY_HTML=body.html
HEAD_HTML=head.html

TARGET_DEV=dev.html
DEV_TMPL_HTML=dev-tmpl.html

PACKED_JS=all.js
SRC:=all-tmpl.js
SRC+=hybrid.js/hybrid.js
SRC+=hybrid.js/view.js
SRC+=../../ext/SimpleWebsocketServer.git/src/websocket.js
SRC+=../../ext/SimpleWebsocketServer.git/src/sha1.js
SRC+=../../ext/SimpleWebsocketServer.git/src/state.js
SRC+=../../ext/SimpleWebsocketServer.git/src/protocol.js
SRC+=setting.js
SRC+=storage.js
SRC+=roi.js
SRC+=protocol.js
SRC+=video.js
SRC+=sound.js
SRC+=effect.js
SRC+=state.js
SRC+=scene.js

PACKED_CSS=all.css
CSS:=all-tmpl.css
CSS+=styles.css
CSS+=hybrid.js/hybrid.css

PACKER=./combine

all: $(PACKER) $(TARGET)

$(PACKER): combine.hs
	ghc --make combine.hs

$(TARGET): $(TMPL_HTML) $(BODY_HTML) $(HEAD_HTML) $(PACKED_JS) $(PACKED_CSS)
	$(PACKER) $< > $@

$(PACKED_JS): $(SRC)
	$(PACKER) all-tmpl.js > $@

$(PACKED_CSS): $(CSS)
	$(PACKER) all-tmpl.css > $@

install: all
	cp $(TARGET) $(INSTALL_DIR)

clean:
	$(RM) $(PACKER) $(PACKED_JS) $(PACKED_CSS) $(TARGET) $(TARGET_DEV) combine.hi combine.o
	cd $(INSTALL_DIR)
	$(RM) $(PACKED_JS) $(PACKED_CSS) $(TARGET) $(TARGET_DEV)
