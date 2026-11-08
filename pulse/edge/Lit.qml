import QtQuick
import QtQuick.Effects
import qs
import qs.components

// a scale along the screen edge: lit segments glow, dead ones sit on a separate layer without the effect —
// otherwise the glow would halo the greys too
Item {
    id: root

    property int n
    property real f
    property bool vertical

    Seg { anchors.fill: parent; n: root.n; vertical: root.vertical; f: 0 }
    Seg {
        anchors.fill: parent
        n: root.n
        vertical: root.vertical
        f: root.f
        off: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Skin.glow
            shadowBlur: 0.7
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
