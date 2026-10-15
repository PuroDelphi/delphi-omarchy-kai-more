import QtQuick

Rectangle {
  id: root
  property string text: ""
  property bool primary: false
  property bool compact: false
  property string tooltip: ""
  signal clicked()
  implicitWidth: label.implicitWidth + (compact ? 24 : 38)
  implicitHeight: compact ? 32 : 46
  radius: compact ? 9 : 13
  color: !enabled ? "#242b39" : primary ? (mouse.containsMouse ? "#ffc49f" : "#f5af88") : (mouse.containsMouse ? "#303b4d" : "#202a3a")
  border.color: primary ? "transparent" : "#344054"
  opacity: enabled ? 1 : 0.45
  scale: mouse.pressed ? 0.96 : 1
  Behavior on color { ColorAnimation { duration: 160 } }
  Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    font.family: "Inter"
    font.pixelSize: root.compact ? 11 : 13
    font.weight: Font.DemiBold
    color: root.primary ? "#221b19" : "#e5ebf6"
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    enabled: root.enabled
    onClicked: root.clicked()
  }
}
