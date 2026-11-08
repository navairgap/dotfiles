import QtQuick
import qs

// label: space mono, caps, .14em tracking, grey. the size is px (not font.pixelSize — tracking is derived from it)
Text {
    textFormat: Text.PlainText // labels get foreign strings (networks, devices, windows, tracks): AutoText would load <img src="http://…"> from them
    property real px: 12
    font { family: Skin.mono; pixelSize: px; letterSpacing: px * 0.14; capitalization: Font.AllUppercase }
    color: Skin.grey
}
