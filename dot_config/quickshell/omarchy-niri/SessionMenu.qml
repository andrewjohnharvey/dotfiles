import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel
    property bool opened: false
    property int selected: 0
    property int pending: -1
    readonly property var actions: [
        {label: "Lock", detail: "Secure this session", glyph: "󰌾", command: ["swaylock", "-f"]},
        {label: "Suspend", detail: "Lock and sleep", glyph: "󰤄", command: ["sh", "-c", "swaylock -f && systemctl suspend"]},
        {label: "Log out", detail: "Return to the login screen", glyph: "󰍃", command: ["niri", "msg", "action", "quit"]},
        {label: "Restart", detail: "Reboot this computer", glyph: "󰜉", command: ["systemctl", "reboot"]},
        {label: "Power off", detail: "Shut down this computer", glyph: "⏻", command: ["systemctl", "poweroff"]}
    ]
    function toggle() { opened = !opened; selected = 0; pending = -1; }
    function activate(index) {
        selected = index;
        if (index >= 2 && pending !== index) { pending = index; return; }
        opened = false;
        Quickshell.execDetached(actions[index].command);
    }
    visible: opened
    implicitWidth: 480
    implicitHeight: 530
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "event-horizon-session"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onVisibleChanged: if (visible) keyboard.forceActiveFocus()
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border { width: 2; color: Theme.accent }
        Rectangle {
            width: parent.width; height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.cyan }
                GradientStop { position: 0.5; color: Theme.accent }
                GradientStop { position: 1; color: Theme.green }
            }
        }
        Item {
            id: keyboard
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: { if (panel.pending >= 0) panel.pending = -1; else panel.opened = false; }
            Keys.onUpPressed: { panel.selected = Math.max(0, panel.selected-1); panel.pending = -1; }
            Keys.onDownPressed: { panel.selected = Math.min(panel.actions.length-1, panel.selected+1); panel.pending = -1; }
            Keys.onReturnPressed: panel.activate(panel.selected)
            Keys.onEnterPressed: panel.activate(panel.selected)
            ColumnLayout {
                anchors { fill: parent; margins: 24 }
                spacing: 12
                RowLayout {
                    Text { text: "EVENT HORIZON"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                    Text { text: "ESC to close"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
                }
                Text { text: "Your session"; color: Theme.foreground; font.family: Theme.font; font.pixelSize: 24; Layout.bottomMargin: 10 }
                Repeater {
                    model: panel.actions
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 61
                        color: panel.selected === index ? Theme.surface : "transparent"
                        border { width: panel.selected === index ? 1 : 0; color: panel.pending === index ? Theme.red : Theme.accent }
                        RowLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 16
                            Text { text: row.modelData.glyph; color: panel.pending === row.index ? Theme.red : Theme.cyan; font.family: Theme.font; font.pixelSize: 22; Layout.minimumWidth: 28; Layout.preferredWidth: 28; Layout.maximumWidth: 28; horizontalAlignment: Text.AlignHCenter }
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; Layout.alignment: Qt.AlignLeft; horizontalAlignment: Text.AlignLeft; text: row.modelData.label; color: Theme.foreground; font.family: Theme.font; font.pixelSize: 14 }
                                Text { Layout.fillWidth: true; Layout.alignment: Qt.AlignLeft; horizontalAlignment: Text.AlignLeft; text: panel.pending === row.index ? "Press Enter or click again to confirm" : row.modelData.detail; color: panel.pending === row.index ? Theme.red : Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: if (panel.selected !== row.index) { panel.selected = row.index; panel.pending = -1; }
                            onClicked: panel.activate(row.index)
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text { text: "↑ ↓ select   ↵ choose"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
            }
        }
    }
}
