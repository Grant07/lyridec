import QtQuick
import QtTest
import ".." as Lyridec

TestCase {
    id: test
    name: "LyricsViewport"
    when: windowShown
    visible: true
    width: 400
    height: 420

    QtObject {
        id: fake
        property string key: "test"
        property bool playing: false
        property var track: ({ title: "Test recording", artist: "Synthetic", duration: 120 })
        property string artwork: ""
        property real position: 0
        property int offset: 0
        property var document: ({ synced: false, source: "Test", lines: [] })
        property string state: "ready"
        property string message: ""
        property string storageMessage: ""
        property bool cached: false
        property bool hasOverride: false
        property string searchState: "idle"
        property string searchMessage: ""
        property var results: []
        function seek(ms) { position = ms / 1000; }
        function setOffset(ms) { offset = ms; }
        property int retryCount: 0
        function resolve(force) { retryCount++; }
        function search(query) { searchState = "ready"; }
    }

    Lyridec.LyricsView {
        id: view
        width: 340
        height: 360
        service: fake
        reducedMotion: true
        onFocusModeRequested: enabled => focusMode = enabled
    }

    function init() {
        view.page = "lyrics";
        view.keyboardNavigation = false;
        view.focusMode = false;
        view.focus = false;
        fake.key = "test";
        fake.state = "ready";
        fake.message = "";
        mouseMove(test, 399, 419);
        wait(30);
    }

    function test_chromeDoesNotMoveLyrics() {
        fake.position = 1;
        fake.document = {synced:true, source:"Test", lines:[
            {time:0, text:"Previous phrase"}, {time:1000, text:"Current phrase"}, {time:2000, text:"Next phrase"}
        ]};
        wait(80);
        const list = findChild(view, "lyricViewport");
        const beforeHeight = list.height;
        const beforeY = list.contentY;
        verify(!view.chromeVisible);
        mouseMove(view, 160, 10);
        tryCompare(view, "chromeVisible", true);
        compare(list.height, beforeHeight);
        compare(list.contentY, beforeY);
        mouseMove(test, 399, 419);
        tryCompare(view, "chromeVisible", false);
        view.forceActiveFocus(Qt.TabFocusReason);
        verify(view.chromeVisible, "Keyboard entry must expose controls");
        view.page = "details";
        view.keyboardNavigation = false;
        verify(view.chromeVisible, "Options must remain open when the pointer leaves");
    }

    function test_stateRecovery() {
        fake.state = "loading";
        wait(30);
        compare(findChild(view, "stateTitle").text, "Finding lyrics…");
        verify(!findChild(view, "stateRecovery").visible);
        fake.state = "missing";
        wait(30);
        compare(findChild(view, "stateRecovery").label, "Find lyrics");
        fake.state = "error";
        wait(30);
        const retry = findChild(view, "stateRecovery");
        compare(retry.label, "Try again");
        const count = fake.retryCount;
        mouseClick(retry);
        compare(fake.retryCount, count + 1);
        fake.key = "";
        fake.state = "idle";
        wait(30);
        compare(findChild(view, "stateTitle").text, "Nothing playing");
        verify(!retry.visible);
    }

    function test_keyboardScrolling() {
        const lines = [];
        for (let n = 0; n < 40; n++) lines.push({time:-1, text:"Synthetic lyric line " + n});
        fake.document = {synced:false, source:"Test", lines:lines};
        wait(100);
        const list = findChild(view, "lyricViewport");
        verify(list !== null);
        view.forceActiveFocus();
        const before = list.contentY;
        keyClick(Qt.Key_PageDown);
        verify(list.contentY > before, "Untimed lyrics must scroll from the keyboard");
        keyClick(Qt.Key_Home);
        compare(list.contentY, list.originY - list.topMargin);

        view.focusMode = true;
        fake.document = {synced:true, source:"Test", lines:[{time:0, text:"A long lyric phrase ".repeat(60)}]};
        wait(100);
        const focus = findChild(view, "focusViewport");
        verify(focus.contentHeight > focus.height);
        view.forceActiveFocus();
        keyClick(Qt.Key_PageDown);
        verify(focus.contentY > 0, "Overflowing focus lyrics must scroll from the keyboard");
        keyClick(Qt.Key_Home);
        compare(focus.contentY, 0);
        view.focusMode = false;
    }

    function test_searchField() {
        view.openSearch();
        wait(100);
        const field = findChild(view, "lyricSearch");
        verify(field.activeFocus);
        verify(field.height >= 36);
        compare(field.text, "Test recording Synthetic");
    }

    function test_stableReadingPosition() {
        view.page = "lyrics";
        view.focusMode = false;
        view.following = true;
        fake.document = {synced:true, source:"Test", lines:[
            {time:0, text:"A short phrase"},
            {time:1000, text:"A much longer phrase that wraps onto several lines"},
            {time:2000, text:"Short again"},
            {time:3000, text:"The final phrase in this recording"}
        ]};
        const list = findChild(view, "lyricViewport");
        for (let index = 0; index < 4; index++) {
            fake.position = index;
            wait(80);
            const row = list.itemAtIndex(index);
            verify(row !== null);
            verify(Math.abs(row.y - list.contentY - list.readingAnchor) < 1,
                "Wrapped and short phrases must share a stable top position");
        }
    }
}
