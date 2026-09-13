pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import "."
import "../Lyrics.js" as Lyrics

Control {
    id: root
    required property var service
    property bool focusMode: false
    property int textSize: 30
    property real backgroundOpacity: 0.94
    property bool backdropBlur: false
    property real glassIntensity: 1.0
    property bool reducedMotion: false
    property bool hideWhenIdle: false
    property string page: "lyrics"
    property bool following: true
    property bool keyboardNavigation: false
    readonly property bool chromeVisible: pointer.hovered || keyboardNavigation || page !== "lyrics"
        || fileDialog.visible || (hasTrack && service.state !== "ready")
    readonly property var doc: service.document
    readonly property int activeLine: doc.synced ? Lyrics.currentIndex(doc.lines, service.position * 1000 + service.offset) : -1
    readonly property bool hasTrack: service.key !== ""
    readonly property int gutter: width < 360 ? 24 : 40
    readonly property bool effectsAvailable: GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool glassReady: effectsAvailable && glass.status === ShaderEffect.Compiled
    signal focusModeRequested(bool enabled)

    implicitWidth: 440
    implicitHeight: 520
    padding: gutter
    topPadding: width < 360 ? 24 : 30
    bottomPadding: width < 360 ? 20 : 28
    focusPolicy: Qt.StrongFocus
    font.pixelSize: 13
    opacity: hideWhenIdle && !hasTrack ? 0 : 1
    enabled: opacity > 0
    background: Item {
        // The compositor supplies the backdrop; this texture only refracts artwork.
        Item {
            id: glassTexture
            width: 192; height: 192
            visible: false
            layer.enabled: root.effectsAvailable
            Rectangle { anchors.fill: parent; color: root.palette.window }
            Image {
                anchors.fill: parent
                source: root.service.artwork
                sourceSize: Qt.size(192, 192)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
        }
        ShaderEffect {
            id: glass
            anchors.fill: parent
            visible: root.effectsAvailable && status !== ShaderEffect.Error
            readonly property var source: glassTexture
            readonly property size panelSize: Qt.size(width, height)
            readonly property color tint: root.palette.window
            readonly property real strength: root.backgroundOpacity
            readonly property real backdrop: root.backdropBlur ? 1 : 0
            readonly property real intensity: Math.max(0, Math.min(1, root.glassIntensity))
            fragmentShader: "../shaders/glass.frag.qsb"
        }
        Rectangle {
            anchors.fill: parent
            visible: !glass.visible
            radius: 24
            color: root.palette.window
            opacity: root.backgroundOpacity
            border.width: 1
            border.color: Qt.rgba(root.palette.windowText.r, root.palette.windowText.g, root.palette.windowText.b, 0.12)
        }
    }

    HoverHandler {
        id: pointer
        onHoveredChanged: if (hovered) root.keyboardNavigation = false
    }
    onActiveFocusChanged: if (activeFocus && (focusReason === Qt.TabFocusReason || focusReason === Qt.BacktabFocusReason)) keyboardNavigation = true
    Connections {
        target: root.Window.window
        function onActiveChanged() { if (!root.Window.active) root.keyboardNavigation = false; }
    }

    Keys.onPressed: event => {
        keyboardNavigation = true;
        if (event.key === Qt.Key_Escape && page !== "lyrics") {
            page = "lyrics";
            forceActiveFocus();
            event.accepted = true;
            return;
        }
        if (page !== "lyrics" || service.state !== "ready") return;
        const viewport = focusMode ? focusFlick : lyricList;
        const top = focusMode ? 0 : lyricList.originY - lyricList.topMargin;
        const bottom = Math.max(top, viewport.contentHeight - viewport.height
            + (focusMode ? 0 : lyricList.originY + lyricList.bottomMargin));
        let next = viewport.contentY;
        switch (event.key) {
        case Qt.Key_Up: next -= 40; break;
        case Qt.Key_Down: next += 40; break;
        case Qt.Key_PageUp: next -= viewport.height * 0.8; break;
        case Qt.Key_PageDown: next += viewport.height * 0.8; break;
        case Qt.Key_Home: next = top; break;
        case Qt.Key_End: next = bottom; break;
        default: return;
        }
        scrollMotion.stop();
        following = false;
        viewport.contentY = Math.max(top, Math.min(bottom, next));
        event.accepted = true;
    }

    Connections {
        target: root.service
        function onKeyChanged() {
            root.page = "lyrics";
            root.following = true;
            searchField.text = "";
        }
        function onDocumentChanged() {
            root.following = true;
            Qt.callLater(root.follow);
        }
    }

    onActiveLineChanged: if (following) Qt.callLater(follow)
    onFocusModeChanged: Qt.callLater(follow)
    onTextSizeChanged: if (following) Qt.callLater(follow)

    function follow() {
        if (!doc.synced || !doc.lines.length) return;
        scrollMotion.stop();
        lyricList.forceLayout();
        const previous = lyricList.contentY;
        const index = Math.max(0, activeLine);
        lyricList.positionViewAtIndex(index, ListView.Beginning);
        const line = lyricList.itemAtIndex(index);
        if (!line) return;
        // Keep the phrase's first line fixed even when the previous verse wrapped.
        const next = line.y - lyricList.readingAnchor;
        if (!reducedMotion && Math.abs(next - previous) < lyricList.height * 2) {
            lyricList.contentY = previous;
            scrollMotion.from = previous;
            scrollMotion.to = next;
            scrollMotion.start();
        } else lyricList.contentY = next;
    }

    NumberAnimation {
        id: scrollMotion
        target: lyricList
        property: "contentY"
        duration: 280
        easing.type: Easing.OutCubic
    }

    FileDialog {
        id: fileDialog
        property string targetKey: ""
        title: "Choose lyrics for " + root.service.track.title
        nameFilters: ["Lyrics (*.lrc *.txt)"]
        onVisibleChanged: if (visible) targetKey = root.service.key
        onAccepted: root.service.importLyrics(selectedFile, targetKey)
    }

    contentItem: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: root.page !== "lyrics" || (root.hasTrack && root.service.state !== "ready") ? 64 : 0
            spacing: 20
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: lyricList
                    objectName: "lyricViewport"
                    readonly property real readingAnchor: height < 170 ? 4 : height * 0.3
                    anchors.fill: parent
                    visible: root.page === "lyrics" && root.service.state === "ready" && !root.focusMode
                    model: root.doc.lines
                    spacing: 24
                    boundsBehavior: Flickable.StopAtBounds
                    topMargin: root.doc.synced ? readingAnchor : 4
                    bottomMargin: root.doc.synced ? height - readingAnchor : 4
                    reuseItems: true
                    layer.enabled: root.effectsAvailable && ((root.doc.synced && root.following) || root.chromeVisible)
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: lyricFade
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    onMovementStarted: { scrollMotion.stop(); root.following = false; }
                    onHeightChanged: if (root.following) Qt.callLater(root.follow)
                    onWidthChanged: if (root.following) Qt.callLater(root.follow)
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: ItemDelegate {
                        id: lineDelegate
                        required property var modelData
                        required property int index
                        readonly property bool current: root.doc.synced && index === root.activeLine
                        readonly property int distance: index - root.activeLine
                        width: lyricList.width - 8
                        height: lyricText.implicitHeight + 8
                        padding: 0
                        hoverEnabled: root.doc.synced
                        focusPolicy: root.doc.synced ? Qt.StrongFocus : Qt.NoFocus
                        Accessible.name: modelData.text || "Instrumental break"
                        Accessible.description: root.doc.synced ? "Seek to " + Lyrics.timeLabel(modelData.time / 1000) : ""
                        onClicked: if (root.doc.synced) { root.service.seek(modelData.time); root.following = true; }
                        background: Rectangle {
                            color: lineDelegate.hovered ? root.palette.button : "transparent"
                            radius: 6
                            border.width: lineDelegate.visualFocus ? 2 : 0
                            border.color: root.palette.highlight
                        }
                        contentItem: Text {
                            id: lyricText
                            text: lineDelegate.modelData.text || "···"
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: root.palette.windowText
                            opacity: !root.doc.synced || !root.following || lineDelegate.current ? 1
                                : lineDelegate.distance === 1 ? 0.43 : lineDelegate.distance === -1 ? 0.3 : 0.22
                            font.family: root.font.family
                            font.pixelSize: root.textSize
                            font.weight: Font.Medium
                            lineHeight: 1.12
                            Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 220 } }
                        }
                    }
                }

                Rectangle {
                    id: lyricFade
                    visible: false
                    width: 2; height: 256
                    layer.enabled: true
                    gradient: Gradient {
                        GradientStop { position: headerChrome.opacity * 0.12; color: lyricList.height < 170 && !root.chromeVisible ? "white" : "transparent" }
                        GradientStop { position: 0.08 + headerChrome.opacity * 0.14; color: "white" }
                        GradientStop { position: 0.68; color: "white" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                Flickable {
                    id: focusFlick
                    objectName: "focusViewport"
                    layer.enabled: root.effectsAvailable && root.chromeVisible
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: lyricFade
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    anchors.fill: parent
                    visible: root.page === "lyrics" && root.service.state === "ready" && root.focusMode
                    contentHeight: Math.max(height, focusWords.height)
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    Column {
                        id: focusWords
                        width: parent.width
                        y: Math.max(0, (focusFlick.height - height) / 2 - 8)
                        spacing: 20
                        Text {
                            width: parent.width
                            text: root.doc.synced ? root.activeLine < 0 ? "Lyrics start soon"
                                : root.doc.lines[root.activeLine]?.text || "Instrumental break"
                                : "Untimed lyrics"
                            textFormat: Text.PlainText
                            color: root.palette.windowText
                            font.family: root.font.family
                            font.pixelSize: root.textSize + 4
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            lineHeight: 1.12
                        }
                        Text {
                            width: parent.width
                            text: root.doc.synced ? root.doc.lines[Math.max(0, root.activeLine + 1)]?.text || ""
                                                  : ""
                            textFormat: Text.PlainText
                            color: root.palette.windowText
                            opacity: 0.43
                            font.family: root.font.family
                            font.pixelSize: Math.max(16, root.textSize - 8)
                            wrapMode: Text.Wrap
                        }
                        LyridecButton {
                            visible: !root.doc.synced
                            label: "Read lyrics"
                            onClicked: root.focusModeRequested(false)
                        }
                    }
                }

                Flickable {
                    id: stateViewport
                    anchors.fill: parent
                    visible: root.page === "lyrics" && root.service.state !== "ready"
                    contentHeight: Math.max(height, stateWords.height)
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    Column {
                        id: stateWords
                        width: Math.min(parent.width, 320)
                        x: (parent.width - width) / 2
                        y: Math.max(0, (stateViewport.height - height) / 2 - 8)
                        spacing: 14
                        BusyIndicator {
                            width: 26; height: 26
                            visible: root.service.state === "loading" && !root.reducedMotion
                            running: visible && stateViewport.visible
                            Accessible.name: "Loading lyrics"
                        }
                        Text {
                            objectName: "stateTitle"
                            width: parent.width
                            text: ({ idle: "Nothing playing", loading: "Finding lyrics…", missing: "No lyrics for this song",
                                instrumental: "Instrumental", error: "Couldn’t load lyrics" })[root.service.state] || ""
                            textFormat: Text.PlainText
                            font.family: root.font.family
                            font.pixelSize: 24
                            font.weight: Font.Medium
                            color: root.palette.windowText
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            text: ({ idle: "Play a song in Spotify to see its lyrics.",
                                missing: "Find another match or use a local lyric file.",
                                instrumental: "This version is listed without vocals.",
                                error: root.service.message || "Try again, or choose another match." })[root.service.state] || ""
                            visible: text !== ""
                            textFormat: Text.PlainText
                            font.family: root.font.family
                            font.pixelSize: 14
                            lineHeight: 1.25
                            color: root.palette.placeholderText
                            wrapMode: Text.Wrap
                        }
                        Column {
                            width: parent.width
                            spacing: 18
                            topPadding: 8
                            visible: root.service.state === "loading"
                            Repeater {
                                model: [0.94, 0.72, 0.84]
                                Rectangle {
                                    required property real modelData
                                    width: stateWords.width * modelData
                                    height: 8
                                    radius: 4
                                    color: root.palette.windowText
                                    opacity: 0.09
                                }
                            }
                        }
                        Flow {
                            width: parent.width
                            spacing: 6
                            visible: root.hasTrack && ["missing", "error", "instrumental"].includes(root.service.state)
                            LyridecButton {
                                objectName: "stateRecovery"
                                selected: true
                                label: root.service.state === "error" ? "Try again" : root.service.state === "instrumental" ? "Find another version" : "Find lyrics"
                                onClicked: root.service.state === "error" ? root.service.resolve(true) : root.openSearch()
                            }
                            LyridecButton {
                                label: root.service.state === "error" ? "Find lyrics" : "Import file"
                                onClicked: root.service.state === "error" ? root.openSearch() : fileDialog.open()
                            }
                        }
                    }
                }

                ScrollView {
                    anchors.fill: parent
                    visible: root.page === "details"
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: parent.width
                        spacing: 14
                        Text {
                            Layout.fillWidth: true
                            text: root.doc.source ? root.doc.source + (root.service.cached ? " · cached" : "") : "Lyrics options"
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: root.palette.windowText
                            font.family: root.font.family; font.pixelSize: 16; font.weight: Font.DemiBold
                        }
                        RowLayout {
                            LyridecButton {
                                label: "Reading"
                                selected: !root.focusMode
                                onClicked: root.focusModeRequested(false)
                            }
                            LyridecButton {
                                label: "Focus"
                                selected: root.focusMode
                                onClicked: root.focusModeRequested(true)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.doc.synced ? "Line-synced lyrics" : "Untimed lyrics"
                            visible: root.doc.lines.length > 0
                            color: root.palette.placeholderText
                            font.family: root.font.family; font.pixelSize: 13
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4
                            LyridecButton { label: "Change match"; enabled: root.hasTrack; onClicked: root.openSearch() }
                            LyridecButton { label: "Import LRC / text"; enabled: root.hasTrack; onClicked: fileDialog.open() }
                            LyridecButton { label: "Reset match"; visible: root.service.hasOverride; onClicked: root.service.clearOverride() }
                        }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.palette.mid }
                        Text {
                            text: "Timing for this song"
                            color: root.palette.windowText
                            font.family: root.font.family; font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            LyridecButton { symbol: "minus"; label: "Show lyrics 0.1 seconds later"; enabled: root.hasTrack; onClicked: root.service.setOffset(root.service.offset - 100) }
                            Text {
                                Layout.fillWidth: true
                                text: (root.service.offset > 0 ? "+" : "") + (root.service.offset / 1000).toFixed(1) + " s"
                                horizontalAlignment: Text.AlignHCenter
                                color: root.palette.windowText
                                font.family: root.font.family; font.pixelSize: 18
                            }
                            LyridecButton { symbol: "plus"; label: "Show lyrics 0.1 seconds earlier"; enabled: root.hasTrack; onClicked: root.service.setOffset(root.service.offset + 100) }
                            LyridecButton { label: "Reset"; enabled: root.service.offset !== 0; onClicked: root.service.setOffset(0) }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Positive values show lyrics earlier. Saved per recording."
                            color: root.palette.placeholderText
                            font.family: root.font.family; font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        LyridecButton {
                            label: "Open in LRCLIB"
                            visible: root.doc.recordId > 0
                            onClicked: Qt.openUrlExternally("https://lrclib.net/tracks/" + root.doc.recordId)
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    visible: root.page === "search"
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: searchField
                            objectName: "lyricSearch"
                            Layout.fillWidth: true
                            Layout.minimumHeight: 36
                            leftPadding: 12
                            rightPadding: 12
                            placeholderText: "Song title and artist"
                            selectByMouse: true
                            maximumLength: 300
                            Accessible.name: "Search lyrics by song title and artist"
                            background: Rectangle {
                                radius: 8
                                color: root.palette.base
                                border.width: searchField.activeFocus ? 2 : 1
                                border.color: searchField.activeFocus ? root.palette.highlight : root.palette.mid
                            }
                            onAccepted: root.service.search(text)
                        }
                        LyridecButton { symbol: "search"; label: "Search lyrics"; onClicked: root.service.search(searchField.text) }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.service.searchState === "loading" || root.service.searchMessage !== ""
                        text: root.service.searchState === "loading" ? "Searching LRCLIB…" : root.service.searchMessage
                        textFormat: Text.PlainText
                        color: root.palette.placeholderText
                        wrapMode: Text.Wrap
                        font.family: root.font.family; font.pixelSize: 13
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.service.results
                        spacing: 6
                        clip: true
                        ScrollBar.vertical: ScrollBar { }
                        delegate: ItemDelegate {
                            id: matchDelegate
                            required property var modelData
                            width: ListView.view.width
                            height: matchText.implicitHeight + 22
                            Accessible.name: modelData.trackName + ", " + modelData.artistName
                            onClicked: { root.service.choose(modelData); root.page = "lyrics"; }
                            contentItem: Column {
                                id: matchText
                                spacing: 4
                                Text {
                                    width: parent.width
                                    text: matchDelegate.modelData.trackName
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: root.palette.windowText
                                    font.family: root.font.family; font.pixelSize: 14; font.weight: Font.DemiBold
                                }
                                Text {
                                    width: parent.width
                                    text: matchDelegate.modelData.artistName + " · " + Lyrics.timeLabel(matchDelegate.modelData.duration)
                                        + " · " + (matchDelegate.modelData.syncedLyrics ? "Synced" : matchDelegate.modelData.instrumental ? "Instrumental" : "Text")
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: root.palette.placeholderText
                                    font.family: root.font.family; font.pixelSize: 12
                                }
                                Text {
                                    width: parent.width
                                    text: matchDelegate.modelData.albumName || ""
                                    textFormat: Text.PlainText
                                    visible: text !== ""
                                    elide: Text.ElideRight
                                    color: root.palette.placeholderText
                                    font.family: root.font.family; font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.service.storageMessage !== "" || (root.service.message !== "" && root.service.state !== "error")
                text: root.service.storageMessage || root.service.message
                textFormat: Text.PlainText
                color: root.palette.windowText
                wrapMode: Text.Wrap
                font.family: root.font.family; font.pixelSize: 12
            }

            LyridecButton {
                Layout.alignment: Qt.AlignHCenter
                visible: root.page === "lyrics" && !root.focusMode && !root.following && root.doc.synced
                label: "Back to current line"
                onClicked: { root.following = true; root.follow(); }
            }

        }

        Item {
            id: headerChrome
            objectName: "headerChrome"
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 44
            opacity: root.chromeVisible ? 1 : 0
            visible: opacity > 0
            enabled: root.chromeVisible
            Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 180 } }
            RowLayout {
                anchors.fill: parent
                spacing: 16
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        Layout.fillWidth: true
                        text: root.hasTrack ? root.service.track.title : "lyridec"
                        textFormat: Text.PlainText
                        color: root.palette.windowText
                        font.family: root.font.family
                        font.pixelSize: root.width < 360 ? 14 : 16; font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.service.track.artist
                        visible: root.hasTrack
                        textFormat: Text.PlainText
                        color: root.palette.placeholderText
                        font.family: root.font.family
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
                LyridecButton {
                    objectName: "lyricsOptions"
                    enabled: root.hasTrack || root.page !== "lyrics"
                    symbol: root.page === "lyrics" ? "more" : "close"
                    label: root.page === "lyrics" ? "Lyrics options" : "Back to lyrics"
                    onClicked: root.page = root.page === "lyrics" ? "details" : "lyrics"
                }
            }

        }
        Item {
            id: footerChrome
            objectName: "footerChrome"
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 20
            opacity: root.chromeVisible && root.page === "lyrics" && root.service.state === "ready" ? 1 : 0
            visible: opacity > 0
            enabled: false
            Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 180 } }
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: root.doc.source + (root.doc.lines.length && !root.doc.synced ? " · untimed" : "")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.palette.placeholderText
                    font.family: root.font.family; font.pixelSize: 12
                }
                Text {
                    visible: root.hasTrack
                    text: (root.service.playing ? "" : "Paused · ") + Lyrics.timeLabel(root.service.position)
                        + (root.service.track.duration > 0 ? " / " + Lyrics.timeLabel(root.service.track.duration) : "")
                    color: root.palette.placeholderText
                    font.family: root.font.family; font.pixelSize: 11
                }
            }
        }
    }

    function openSearch() {
        page = "search";
        searchField.text = service.track.title + " " + service.track.artist;
        searchField.forceActiveFocus();
        service.search(searchField.text);
    }
}
