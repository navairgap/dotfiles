import QtQuick
import qs

// canvas in 1920×1080 layout pixels: stretched over the parent, everything inside measures as in concept.html
Item {
    width: parent.width / Skin.s
    height: parent.height / Skin.s
    scale: Skin.s
    transformOrigin: Item.TopLeft
}
