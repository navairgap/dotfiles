import QtQuick
import qs

// pill over the frame: surface with a raised border, content in a centered row. clicks on it don't fall through to what's under
Rectangle {
    default property alias content: row.data
    property alias spacing: row.spacing
    property real pad: 10

    width: row.width + pad * 2
    height: 56
    radius: height / 2
    color: Skin.s1
    border { width: 1; color: Skin.s2 }

    MouseArea { anchors.fill: parent }
    Row { id: row; anchors.centerIn: parent }
}
