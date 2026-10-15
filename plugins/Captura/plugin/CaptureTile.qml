import QtQuick

Item {
  id: root
  required property var imageData
  property int position: 0
  property bool selected: false
  signal choose()
  signal openImage()
  signal copyImage()
  signal trashImage()
  signal dragFinished(int action)
  property real entrance: 0
  opacity: entrance
  scale: entrance * (hover.hovered ? 1.018 : 1.0)
  Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Component.onCompleted: entranceAnimation.start()
  SequentialAnimation {
    id: entranceAnimation
    PauseAnimation { duration: Math.min(root.position, 8) * 30 }
    NumberAnimation { target: root; property: "entrance"; from: 0.85; to: 1; duration: 300; easing.type: Easing.OutCubic }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: 5
    radius: 15
    color: hover.hovered ? "#253044" : "#1a2434"
    border.width: 1
    border.color: root.selected ? "#f5af88" : hover.hovered ? "#52627b" : "#303c50"
    Behavior on border.color { ColorAnimation { duration: 160 } }
    Behavior on color { ColorAnimation { duration: 180 } }
    Rectangle {
      id: picture
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9 }
      height: parent.height - 80
      radius: 10
      color: "#101825"
      clip: true
      Image {
        id: thumb
        anchors.fill: parent
        source: root.imageData.uri
        sourceSize.width: 540
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
      }
      Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
        width: dimensions.implicitWidth + 13
        height: 23
        radius: 6
        color: "#d9101723"
        Text {
          id: dimensions
          anchors.centerIn: parent
          text: root.imageData.width + " × " + root.imageData.height
          font.pixelSize: 10
          color: "#eef2f9"
        }
      }
    }
    Text {
      anchors { left: parent.left; right: parent.right; top: picture.bottom; leftMargin: 12; rightMargin: 12; topMargin: 9 }
      text: root.imageData.modified
      font.family: "Inter"
      font.pixelSize: 12
      font.weight: Font.Medium
      color: "#e6edf9"
    }
    Text {
      anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 13 }
      text: (root.imageData.bytes / 1048576).toFixed(1) + " MB"
      font.pixelSize: 10
      color: "#92a1b9"
    }
    Row {
      anchors { right: parent.right; bottom: parent.bottom; rightMargin: 10; bottomMargin: 9 }
      spacing: 5
      z: 3
      ActionButton { text: "Copiar"; compact: true; onClicked: root.copyImage() }
      ActionButton { text: "Pinta ↗"; compact: true; onClicked: root.openImage() }
    }
  }
  HoverHandler { id: hover }
  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.choose()
    onDoubleTapped: root.openImage()
  }

  // This is a native QDrag, not an internal QML-only drop. GTK applications
  // receive the PNG's file URI, with copy semantics; the original stays here.
  Drag.active: dragHandler.active
  Drag.dragType: Drag.Automatic
  Drag.supportedActions: Qt.CopyAction
  Drag.proposedAction: Qt.CopyAction
  Drag.mimeData: ({"text/uri-list": root.imageData.uri + "\r\n"})
  Drag.imageSource: root.imageData.uri
  Drag.imageSourceSize: Qt.size(240, 150)
  Drag.hotSpot.x: 90
  Drag.hotSpot.y: 45
  Drag.onDragFinished: action => root.dragFinished(action)
  DragHandler {
    id: dragHandler
    target: null
    acceptedButtons: Qt.LeftButton
  }
}
