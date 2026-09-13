PREFIX ?= /usr
SYSCONFDIR ?= /etc
QT_BINDIR ?= /usr/lib/qt6/bin
QSB ?= $(QT_BINDIR)/qsb
PLUGIN_DIR = $(DESTDIR)$(PREFIX)/share/lyridec
QML_FILES = src/qmldir src/Lyrics.js src/Lyridec.qml src/LyridecSettings.qml

.PHONY: all check check-glass install

all: src/shaders/glass.frag.qsb

src/shaders/glass.frag.qsb: src/shaders/glass.frag
	$(QSB) --qt6 -o $@ $<

check: all
	node tests/unit/lyrics.mjs
	QT_BINDIR="$(QT_BINDIR)" sh tests/check-view.sh
	dbus-run-session -- python3 tests/integration/check-service.py

check-glass: all
	QT_BINDIR="$(QT_BINDIR)" sh tests/check-glass.sh

install: all
	install -dm755 "$(PLUGIN_DIR)/src/components" "$(PLUGIN_DIR)/src/services" "$(PLUGIN_DIR)/src/shaders"
	install -m644 plugin.json "$(PLUGIN_DIR)/"
	install -m644 $(QML_FILES) "$(PLUGIN_DIR)/src/"
	install -m644 src/components/qmldir src/components/*.qml "$(PLUGIN_DIR)/src/components/"
	install -m644 src/services/*.qml "$(PLUGIN_DIR)/src/services/"
	install -m644 src/shaders/glass.frag.qsb "$(PLUGIN_DIR)/src/shaders/"
	install -Dm644 LICENSE "$(DESTDIR)$(PREFIX)/share/licenses/lyridec/LICENSE"
	install -Dm644 README.md "$(DESTDIR)$(PREFIX)/share/doc/lyridec/README.md"
	install -Dm644 docs/design.md "$(DESTDIR)$(PREFIX)/share/doc/lyridec/docs/design.md"
	install -dm755 "$(DESTDIR)$(SYSCONFDIR)/xdg/quickshell/dms-plugins"
	ln -sfn "$(PREFIX)/share/lyridec" "$(DESTDIR)$(SYSCONFDIR)/xdg/quickshell/dms-plugins/lyridec"
