import QtQuick
import qs
import qs.components

// chip, like the launcher's modes: on — white pill, black text; off — grey text
Rectangle {
    property alias text: lb.text
    property bool on
    signal clicked

    width: lb.width + 32
    height: 36
    radius: Skin.corner(18)
    color: on ? Skin.fg : "transparent"
    Behavior on color { ColorAnimation { duration: Skin.t } }

    Lb { id: lb; anchors.centerIn: parent; px: 11; color: parent.on ? Skin.ink : Skin.grey }
    TapHandler { onTapped: parent.clicked() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
