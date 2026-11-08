import QtQuick

// dot mask for layer.effect: `layer.enabled: true; layer.effect: Dm { step: 6 }` — covers, weather, the orb on the wallpaper
ShaderEffect {
    property real step: 5
    readonly property real pitch: step // the shader's uniform: step is taken in glsl
    property bool circle: false // dots inside the circle only
    readonly property real circ: circle ? 1 : 0
    readonly property size size: Qt.size(width, height)
    fragmentShader: Qt.resolvedUrl("shaders/dots.frag.qsb")
}
