import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import qs
import qs.components

// the list under the pills (right click on wi-fi/bluetooth). networks: a tap connects or disconnects, a new secured one asks for a password.
// devices: tapping a paired one connects or drops it, strangers get introduced (pair). scanning only while the list is open
Rectangle {
    id: root
    property string kind // "wifi" | "bt" | "" — closed
    signal touched       // any click inside pins the panel

    readonly property bool isWifi: kind === "wifi"
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool on: isWifi ? Networking.wifiEnabled : bt?.enabled ?? false
    // a network with a sign-in page: vpn opens the portal itself (and drops the tunnel); a tap here just reopens it if the tab got closed
    readonly property bool portal: Networking.connectivity === NetworkConnectivity.Portal

    property var ask: null // the network that wants a password
    property string err
    onKindChanged: { ask = null; err = ""; }
    // the password row is gone — focus back to the panel so esc closes it
    onAskChanged: if (!ask && pw.activeFocus) root.forceActiveFocus()

    Binding { when: root.isWifi && root.on; target: root.wifi; property: "scannerEnabled"; value: true }
    Binding { when: root.kind === "bt" && root.on; target: root.bt; property: "discovering"; value: true }

    // the connected one on top, then saved, then by signal strength. while a password is being typed — only that network: a resort must not eat the typing
    readonly property var nets: !isWifi || !wifi ? [] : wifi.networks.values.filter(n => n.name)
        .sort((a, b) => b.connected - a.connected || b.known - a.known || b.signalStrength - a.signalStrength).slice(0, 6)
    // nameless (address only) — static from the air
    readonly property var devs: kind !== "bt" || !bt ? [] : bt.devices.values.filter(d => d.paired || d.deviceName)
        .sort((a, b) => b.connected - a.connected || b.paired - a.paired).slice(0, 6)
    readonly property var rows: !on ? [] : ask ? [ask] : isWifi ? nets : devs

    function bars(n) {
        const lock = n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
        const i = Math.min(3, Math.floor(n.signalStrength * 4));
        return (lock ? ["\u{F0920}", "\u{F0923}", "\u{F0926}", "\u{F0929}"] : ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"])[i];
    }
    function btIcon(i) {
        return /audio|head/.test(i) ? "\u{F02CB}" : /mouse/.test(i) ? "\u{F037D}" : /keyboard/.test(i) ? "\u{F030C}" : /phone/.test(i) ? "\u{F03F2}" : "\u{F00AF}";
    }
    // enterprise (eap) never reaches here — psk only; if i ever need it, nmcli from settings
    function tap(o) {
        touched();
        err = "";
        if (!isWifi) {
            if (o.pairing) return o.cancelPair();
            if (!o.paired) { o.trusted = true; return o.pair(); }
            return o.connected ? o.disconnect() : o.connect();
        }
        if (o.connected) return portal ? Qt.openUrlExternally("http://neverssl.com") : o.disconnect();
        if (o.known || o.security === WifiSecurityType.Open || o.security === WifiSecurityType.Owe) return o.connect();
        ask = o;
    }

    visible: kind === "wifi" || kind === "bt"
    height: list.height + 32
    radius: Skin.corner(30)
    color: Skin.s2

    Column {
        id: list
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 4

        Item {
            width: parent.width
            height: 24
            Lb {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                text: !root.on ? `${root.isWifi ? "wi-fi" : "bluetooth"} · off`
                    : root.ask ? "password"
                    : root.isWifi ? `networks · ${root.nets.length}` : `devices · ${root.bt?.discovering ? "searching" : root.devs.length}`
            }
            Lb {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                rightPadding: 4
                width: Math.min(implicitWidth, parent.width * 0.6)
                elide: Text.ElideRight
                visible: !!root.err || !!root.ask
                text: root.err || "cancel"
                color: Skin.fg
                TapHandler { onTapped: { root.touched(); root.err = ""; root.ask = null; } }
            }
        }

        Repeater {
            model: root.rows
            Rectangle {
                id: row
                required property var modelData
                readonly property var o: modelData
                readonly property bool on: o.connected
                readonly property bool busy: root.isWifi ? o.stateChanging : o.pairing || o.state === BluetoothDeviceState.Connecting || o.state === BluetoothDeviceState.Disconnecting
                width: list.width
                height: 56
                radius: Skin.corner(28)
                color: hov.hovered ? Skin.s3 : "transparent"

                Rectangle {
                    id: ic
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: row.on ? Skin.fg : Skin.s3
                    Icon {
                        anchors.centerIn: parent
                        text: root.isWifi ? root.bars(row.o) : root.btIcon(row.o.icon)
                        font.pixelSize: 19
                        color: row.on ? Skin.ink : Skin.fg
                        // connecting — the icon breathes
                        SequentialAnimation on opacity {
                            running: row.busy
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) parent.opacity = 1
                            NumberAnimation { to: 0.25; duration: 450 }
                            NumberAnimation { to: 1; duration: 450 }
                        }
                    }
                }
                Column {
                    anchors { left: ic.right; leftMargin: 14; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: row.o.name || row.o.address; font { family: Skin.ui; pixelSize: 15; weight: Font.DemiBold } color: Skin.fg }
                    Lb {
                        px: 10
                        text: root.isWifi
                            ? `${row.on ? (root.portal ? "sign in" : "connected") : row.busy ? "connecting" : row.o.known ? "saved" : WifiSecurityType.toString(row.o.security).toLowerCase()} · ${Math.round(row.o.signalStrength * 100)}%`
                            : (row.o.pairing ? "pairing" : row.o.state === BluetoothDeviceState.Connecting ? "connecting" : row.o.state === BluetoothDeviceState.Disconnecting ? "disconnecting"
                               : row.on ? "connected" : row.o.paired ? "paired" : "pair") + (row.o.batteryAvailable ? ` · ${Math.round(row.o.battery * 100)}%` : "")
                    }
                }
                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.tap(row.o) }
                // right click on a saved one — forget
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.touched(); if (row.o.known || row.o.paired) row.o.forget(); } }
                // no password or a wrong one — NM asks for the secret: the password row comes back
                Connections {
                    target: root.isWifi ? row.o : null
                    ignoreUnknownSignals: true
                    function onConnectionFailed(r) {
                        if (r === ConnectionFailReason.NoSecrets) root.ask = row.o;
                        else root.err = ConnectionFailReason.toString(r);
                    }
                }
            }
        }

        Rectangle {
            visible: !!root.ask
            width: list.width
            height: 56
            radius: Skin.corner(28)
            color: Skin.s1
            border { width: 1; color: Skin.s3 }
            onVisibleChanged: if (visible) pw.forceActiveFocus()
            TextInput {
                id: pw
                anchors { left: parent.left; leftMargin: 22; right: go.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                echoMode: TextInput.Password
                passwordCharacter: "•"
                font { family: Skin.mono; pixelSize: 16; letterSpacing: 2 }
                color: Skin.fg
                selectionColor: Skin.fg
                selectedTextColor: Skin.ink
                clip: true
                onAccepted: if (text) go.send()
                Lb { visible: !pw.text; anchors.verticalCenter: parent.verticalCenter; text: "enter password"; color: Skin.mute }
            }
            Rectangle {
                id: go
                function send() { root.touched(); root.ask.connectWithPsk(pw.text); pw.text = ""; root.ask = null; }
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: 44
                height: 44
                radius: 22
                color: pw.text ? Skin.fg : Skin.s3
                Icon { anchors.centerIn: parent; text: "\u{F0054}"; font.pixelSize: 19; color: pw.text ? Skin.ink : Skin.grey }
                TapHandler { onTapped: if (pw.text) go.send() }
            }
        }

        Lb {
            visible: root.on && !root.ask && !root.rows.length
            x: 4
            topPadding: 4
            bottomPadding: 4
            text: root.isWifi ? "scanning…" : "nothing nearby"
        }
    }
}
