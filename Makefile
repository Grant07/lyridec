PREFIX ?= /usr
SYSCONFDIR ?= /etc
QT_BINDIR ?= /usr/lib/qt6/bin
QSB ?= $(QT_BINDIR)/qsb
PLUGIN_FILES = plugin.json qmldir Lyrics.js LyricsService.qml LyricsView.qml Lyridec.qml LyridecButton.qml LyridecSettings.qml

.PHONY: all check check-glass install

all: shaders/glass.frag.qsb

shaders/glass.frag.qsb: shaders/glass.frag
	$(QSB) --qt6 -o $@ $<

check: all
	node tests/check.mjs
	QT_BINDIR="$(QT_BINDIR)" sh tests/check-view.sh
	dbus-run-session -- python3 tests/check-service.py

check-glass: all
	QT_BINDIR="$(QT_BINDIR)" sh tests/check-glass.sh

install: all
	install -dm755 "$(DESTDIR)$(PREFIX)/share/lyridec/shaders"
	install -m644 $(PLUGIN_FILES) "$(DESTDIR)$(PREFIX)/share/lyridec/"
	install -m644 shaders/glass.frag.qsb "$(DESTDIR)$(PREFIX)/share/lyridec/shaders/"
	install -Dm644 LICENSE "$(DESTDIR)$(PREFIX)/share/licenses/lyridec/LICENSE"
	install -Dm644 README.md "$(DESTDIR)$(PREFIX)/share/doc/lyridec/README.md"
	install -Dm644 DESIGN.md "$(DESTDIR)$(PREFIX)/share/doc/lyridec/DESIGN.md"
	install -dm755 "$(DESTDIR)$(SYSCONFDIR)/xdg/quickshell/dms-plugins"
	ln -sfn "$(PREFIX)/share/lyridec" "$(DESTDIR)$(SYSCONFDIR)/xdg/quickshell/dms-plugins/lyridec"
