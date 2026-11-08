import QtQuick
import qs
import qs.services

// back · play (the red circle — the accent goes to the living) · next
Row {
    id: root

    property real size: 22
    property real play: 52

    spacing: root.size

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F04AE}"
        font.pixelSize: root.size
        color: Media.player?.canGoPrevious ? Skin.fg : Skin.mute
        TapHandler { onTapped: Media.player?.previous() }
    }
    Rectangle {
        width: root.play
        height: root.play
        radius: root.play / 2
        color: Skin.accent
        Icon { anchors.centerIn: parent; text: Media.playing ? "\u{F03E4}" : "\u{F040A}"; color: Skin.on(Skin.accent); font.pixelSize: root.play * 0.46 }
        TapHandler { onTapped: Media.player?.togglePlaying() }
    }
    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F04AD}"
        font.pixelSize: root.size
        color: Media.player?.canGoNext ? Skin.fg : Skin.mute
        TapHandler { onTapped: Media.player?.next() }
    }
}
