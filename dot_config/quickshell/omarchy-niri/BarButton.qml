import QtQuick
Rectangle {
    id: button
    property string text: ""
    property color textColor: Theme.foreground
    property bool active: false
    signal clicked(var mouse)
    signal wheel(var event)
    implicitWidth: label.implicitWidth + 20
    implicitHeight: 30
    color: active ? Theme.surface : (area.containsMouse ? Theme.surface : "transparent")
    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        font.family: Theme.font
        font.pixelSize: 12
        color: button.textColor
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: Theme.accent; visible: button.active }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => button.clicked(mouse)
        onWheel: event => button.wheel(event)
    }
}
