import QtQuick
import qs

// nerd font glyph (material design). the box is 1em, like line-height: 1 in the concept (an nf line is 1.32em)
Text {
    readonly property real lead: -0.16 * font.pixelSize
    font { family: Skin.nf; pixelSize: 19 }
    topPadding: lead
    bottomPadding: lead
    color: Skin.fg
}
