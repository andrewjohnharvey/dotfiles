import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications

ShellRoot {
    id: root
    property var state: ({workspaces: [], title: "", volume: "—", network: "", cpu: 0, memory: 0, battery: ""})
    property bool launcherOpen: false
    property string query: ""
    property int selection: 0
    property var apps: DesktopEntries.applications.values.slice().sort((a,b) => a.name.localeCompare(b.name))
    property var filteredApps: apps.filter(a => (a.name + " " + (a.genericName || "") + " " + (a.comment || "")).toLowerCase().includes(query.toLowerCase())).slice(0, 40)
    property string timeText: ""
    property string dateText: ""

    function launch(args) { Quickshell.execDetached(args); }
    function toggleLauncher() { launcherOpen = !launcherOpen; query = ""; selection = 0; }
    function openApp(index) {
        if (index >= 0 && index < filteredApps.length) {
            filteredApps[index].execute(); launcherOpen = false;
        }
    }
    function focusWorkspace(id) { root.launch(["python3", Quickshell.shellPath("bridge.py"), "focus", id.toString()]); }
    function clockTick() {
        const now = new Date();
        timeText = Qt.formatDateTime(now, "ddd  MMM d   HH:mm");
        dateText = Qt.formatDateTime(now, "dddd, MMMM d, yyyy");
    }
    Component.onCompleted: clockTick()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.clockTick() }
    Process {
        id: bridge
        command: ["python3", Quickshell.shellPath("bridge.py")]
        running: true
        stdout: SplitParser {
            onRead: data => { try { root.state = JSON.parse(data); } catch (error) { console.warn("Status:", error); } }
        }
        onExited: restartBridge.start()
    }
    Timer { id: restartBridge; interval: 2000; onTriggered: bridge.running = true }
    IpcHandler {
        target: "shell"
        function launcher(): void { sessionMenu.opened = false; root.toggleLauncher(); }
        function session(): void { root.launcherOpen = false; sessionMenu.toggle(); }
        function closeSession(): void { sessionMenu.opened = false; }
        function closeLauncher(): void { root.launcherOpen = false; }
        function status(): string { return JSON.stringify({launcherOpen: root.launcherOpen, sessionOpen: sessionMenu.opened, applications: root.apps.length, notifications: notifications.trackedNotifications.values.length, state: root.state}); }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "omarchy-niri-wallpaper"
            color: Theme.background
            Image { anchors.fill: parent; source: Qt.resolvedUrl("event-horizon.jpg"); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            // A transparent edge catches hover without lighting a static strip.
            property bool expanded: false
            property int openMenus: 0
            implicitHeight: expanded ? 30 : 1
            color: expanded ? Theme.background : "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "omarchy-niri-bar"
            function updateVisibility() {
                if (barHover.hovered || openMenus > 0) {
                    hideBar.stop();
                    expanded = true;
                } else {
                    hideBar.restart();
                }
            }
            onOpenMenusChanged: updateVisibility()
            HoverHandler {
                id: barHover
                onHoveredChanged: bar.updateVisibility()
            }
            Timer {
                id: hideBar
                interval: 400
                onTriggered: if (!barHover.hovered && bar.openMenus === 0) bar.expanded = false
            }
            IpcHandler {
                target: "bar-" + bar.screen.name
                function status(): string {
                    return JSON.stringify({expanded: bar.expanded, hovered: barHover.hovered, height: bar.height, openMenus: bar.openMenus});
                }
            }
            Item {
                anchors.fill: parent
                visible: bar.expanded
                RowLayout {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                    spacing: 2
                    BarButton { text: "◈"; textColor: Theme.accent; onClicked: root.toggleLauncher() }
                    Repeater {
                        model: root.state.workspaces.filter(w => w.output === bar.screen.name)
                        BarButton {
                            required property var modelData
                            text: modelData.name || modelData.idx.toString()
                            active: modelData.is_active
                            textColor: modelData.is_urgent ? Theme.red : (active ? Theme.accent : Theme.muted)
                            onClicked: root.focusWorkspace(modelData.id)
                        }
                    }
                    Text {
                        text: root.state.title
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.maximumWidth: Math.max(0, bar.width * 0.23)
                        Layout.leftMargin: 14
                    }
                }
                BarButton {
                    anchors.centerIn: parent
                    text: root.timeText
                    onClicked: root.launch(["notify-send", "Calendar", root.dateText])
                }
                RowLayout {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                    spacing: 0
                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            id: trayItem
                            required property var modelData
                            implicitWidth: 28; implicitHeight: 30
                            Image { anchors.centerIn: parent; width: 16; height: 16; source: trayItem.modelData.icon }
                            QsMenuAnchor {
                                id: trayMenu
                                menu: trayItem.modelData.menu
                                onOpened: bar.openMenus += 1
                                onClosed: bar.openMenus = Math.max(0, bar.openMenus - 1)
                                anchor.window: bar
                                anchor.rect.x: trayItem.x + trayItem.parent.x
                                anchor.rect.y: 30
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) trayMenu.open();
                                    else if (mouse.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate();
                                    else trayItem.modelData.activate();
                                }
                            }
                        }
                    }
                    BarButton {
                        text: "CPU " + root.state.cpu + "%"
                        textColor: Theme.muted
                        onClicked: root.launch(["/home/andy/.local/bin/ghostty", "-e", "top"])
                    }
                    BarButton { text: "RAM " + root.state.memory + "G"; textColor: Theme.muted; onClicked: root.launch(["/home/andy/.local/bin/ghostty", "-e", "top"]) }
                    BarButton { text: root.state.network; textColor: root.state.network === "OFFLINE" ? Theme.red : Theme.green; onClicked: root.launch(["nm-connection-editor"]) }
                    BarButton {
                        text: "VOL " + root.state.volume
                        onClicked: mouse => root.launch(mouse.button === Qt.RightButton ? ["gnome-control-center", "sound"] : ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                        onWheel: event => root.launch(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", event.angleDelta.y > 0 ? "5%+" : "5%-", "-l", "1.0"])
                    }
                    BarButton { visible: root.state.battery !== ""; text: "BAT " + root.state.battery }
                    BarButton { text: "⏻"; textColor: Theme.accent; onClicked: root.launch(["/home/andy/.local/bin/niri-session-menu"]) }
                }
            }
        }
    }

    PanelWindow {
        id: launcher
        visible: root.launcherOpen
        // Follow the output containing the focused niri workspace.
        screen: Quickshell.screens.find(s => root.state.workspaces.some(w => w.is_focused && w.output === s.name)) || Quickshell.screens[0]
        implicitWidth: 640
        implicitHeight: 510
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "omarchy-niri-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) search.forceActiveFocus()
        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border { width: 2; color: Theme.accent }
            ColumnLayout {
                anchors { fill: parent; margins: 22 }
                spacing: 12
                RowLayout {
                    Text { text: "APPLICATIONS"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 12; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "ESC to close"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    color: Theme.surface
                    TextInput {
                        id: search
                        anchors { fill: parent; margins: 12 }
                        color: Theme.foreground
                        selectionColor: Theme.accent
                        font.family: Theme.font; font.pixelSize: 16
                        clip: true
                        text: root.query
                        onTextEdited: { root.query = text; root.selection = 0; }
                        Text { text: "Search applications…"; color: Theme.muted; visible: search.text.length === 0; font: search.font }
                        Keys.onEscapePressed: root.launcherOpen = false
                        Keys.onReturnPressed: root.openApp(root.selection)
                        Keys.onEnterPressed: root.openApp(root.selection)
                        Keys.onDownPressed: root.selection = Math.min(root.filteredApps.length-1, root.selection+1)
                        Keys.onUpPressed: root.selection = Math.max(0, root.selection-1)
                    }
                }
                ListView {
                    id: appList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    model: root.filteredApps
                    currentIndex: root.selection
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    spacing: 2
                    delegate: Rectangle {
                        id: appRow
                        required property var modelData
                        required property int index
                        width: appList.width; height: 44
                        color: index === root.selection ? Theme.surface : "transparent"
                        Rectangle { visible: appRow.index === root.selection; width: 2; height: parent.height; color: Theme.accent }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            spacing: 12
                            Image { source: Quickshell.iconPath(appRow.modelData.icon, true); Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                            Text { text: appRow.modelData.name; color: Theme.foreground; font.family: Theme.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: "↵"; visible: appRow.index === root.selection; color: Theme.accent; font.pixelSize: 16 }
                        }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.selection = appRow.index; onClicked: root.openApp(appRow.index) }
                    }
                    Text { visible: root.filteredApps.length === 0; text: "No matching applications"; color: Theme.muted; anchors.centerIn: parent; font.family: Theme.font }
                }
                Text { text: "↑ ↓ select     ↵ launch"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
            }
        }
    }

    SessionMenu {
        id: sessionMenu
        screen: Quickshell.screens.find(s => root.state.workspaces.some(w => w.is_focused && w.output === s.name)) || Quickshell.screens[0]
    }

    NotificationServer {
        id: notifications
        bodySupported: true
        actionsSupported: true
        onNotification: notification => { notification.tracked = true; }
    }
    PanelWindow {
        screen: Quickshell.screens.find(s => root.state.workspaces.some(w => w.is_focused && w.output === s.name)) || Quickshell.screens[0]
        visible: notifications.trackedNotifications.values.length > 0
        anchors { top: true; right: true }
        margins { top: 42; right: 12 }
        implicitWidth: 380
        implicitHeight: notificationColumn.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "omarchy-niri-notifications"
        Column {
            id: notificationColumn
            width: parent.width
            spacing: 8
            Repeater {
                model: notifications.trackedNotifications
                delegate: Rectangle {
                    id: toast
                    required property var modelData
                    width: notificationColumn.width
                    implicitHeight: toastContent.implicitHeight + 28
                    color: Theme.background
                    border { width: 1; color: Theme.accent }
                    Timer {
                        interval: toast.modelData.expireTimeout > 0 ? toast.modelData.expireTimeout : 6000
                        running: toast.modelData.urgency !== 2 && toast.modelData.expireTimeout !== 0
                        onTriggered: toast.modelData.expire()
                    }
                    ColumnLayout {
                        id: toastContent
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                        spacing: 8
                        RowLayout {
                            Text { text: toast.modelData.appName || "Notification"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                            Text { text: "×"; color: Theme.muted; font.pixelSize: 18; MouseArea { anchors.fill: parent; onClicked: toast.modelData.dismiss() } }
                        }
                        Text { text: toast.modelData.summary; textFormat: Text.PlainText; color: Theme.foreground; font.family: Theme.font; font.pixelSize: 13; font.bold: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        Text { text: toast.modelData.body; visible: text !== ""; textFormat: Text.PlainText; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: toast.modelData.actions
                                delegate: BarButton {
                                    required property var modelData
                                    text: modelData.text
                                    active: true
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
