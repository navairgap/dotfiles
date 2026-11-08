import QtQuick
import qs

// the bar: a column at the left edge, a row at the top (Skin.state.barAt); centered across. columns only — the grid counts rows itself,
// else on an edge change columns and rows take turns and for a moment it's 1×1 ("more visible items than rows*columns" in the log).
// its own file, not an inline component: a new inline component breaks hot reload ("is not a type") until qs restarts
Grid {
    readonly property bool vert: Skin.state.barAt !== "top"
    columns: vert ? 1 : 99
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
}
