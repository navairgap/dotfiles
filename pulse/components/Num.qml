import QtQuick
import qs

// digits and short words: Doto, round dots (ROND 100). never under 26px.
// the box is line-height .85 in the concept: lineHeight does nothing on a single-line Text, so negative padding instead
// (a Doto line is 1.2em → .85em). own spacing — `topPadding: lead + 8`
Text {
    textFormat: Text.PlainText
    readonly property real lead: -0.175 * font.pixelSize
    font { family: Skin.dot; pixelSize: 44; weight: Font.Black; variableAxes: ({ "ROND": 100, "wght": 900 }) }
    topPadding: lead
    bottomPadding: lead
    color: Skin.fg
}
