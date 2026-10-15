import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui as Ui

Ui.BarWidget {
  id: root
  moduleName: "purodelphi.captura"
  implicitWidth: barButton.implicitWidth
  implicitHeight: barSize
  readonly property bool opened: gallery.visible
  readonly property string directory: setting("directory", Quickshell.env("HOME") + "/Pictures/Capturas")
  readonly property string executable: localPath(Qt.resolvedUrl("../bin/CapturaBackend"))
  readonly property string actions: localPath(Qt.resolvedUrl("../actions.sh"))
  property int mode: 0
  property string lastCatalog: ""
  property string selectedPath: ""
  property string notice: ""
  property bool noticeError: false
  property bool capturing: captureDelay.running || captureProcess.running
  property string captureResult: ""
  property string captureError: ""
  property int captureCount: 0
  property real totalBytes: 0
  property bool catalogReady: false
  property string filter: ""
  property int catalogVersion: 0

  function localPath(url) { return decodeURIComponent(String(url).replace(/^file:\/\//, "")) }
  function open() { dismiss.stop(); gallery.visible = true; reveal.restart(); refresh() }
  function close() { dismiss.restart() }
  function toggle() { opened ? close() : open() }
  function refresh() {
    if (!catalogProcess.running) {
      catalogProcess.command = [executable, "list", directory]
      catalogProcess.running = true
    }
  }
  function showNotice(text, error) {
    notice = text; noticeError = !!error; noticeTimer.restart()
  }
  function capture() {
    if (capturing) return
    close()
    captureResult = ""; captureError = ""
    captureDelay.start()
  }
  function action(verb, path) {
    if (verb === "pinta") { Quickshell.execDetached(["pinta", path]); showNotice("Abriendo en Pinta…", false); return }
    if (verb === "folder") { Quickshell.execDetached(["xdg-open", directory]); return }
    if (actionProcess.running) return
    actionProcess.command = [actions, verb, path || directory]
    actionProcess.running = true
    showNotice(verb === "copy" ? "Imagen copiada al portapapeles" : verb === "trash" ? "Captura enviada a la papelera" : "Abriendo…", false)
  }
  function loadCatalog(text) {
    try {
      var data = JSON.parse(text)
      if (data.error) { showNotice(data.error, true); return }
      catalogReady = true
      captureCount = data.count
      totalBytes = data.totalBytes
      if (lastCatalog === text) return
      lastCatalog = text
      var visibleItems = data.items.filter(item => !filter || item.name.toLowerCase().indexOf(filter.toLowerCase()) >= 0)
      captures.clear()
      for (var i = 0; i < visibleItems.length; i++) captures.append(visibleItems[i])
      catalogVersion++
    } catch (e) { showNotice("No se pudo leer el catálogo de capturas", true) }
  }

  Ui.WidgetButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: "󰄀"
    tooltipText: "Captura · tu galería de capturas"
    foreground: root.opened ? "#f5af88" : root.bar ? root.bar.barForeground : Color.foreground
    onPressed: button => {
      if (button === Qt.RightButton) root.capture()
      else root.toggle()
    }
  }

  IpcHandler {
    target: "purodelphi.captura"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function capture(mode: string): void { root.mode = mode === "fullscreen" ? 1 : mode === "windows" ? 2 : 0; root.capture() }
    function refresh(): void { root.refresh() }
    function count(): int { return root.captureCount }
    function status(): string { return JSON.stringify({opened:root.opened, ready:root.catalogReady, count:root.captureCount, directory:root.directory, notice:root.notice, capturing:root.capturing}) }
  }

  ListModel { id: captures }
  Timer { interval: 5000; running: gallery.visible; repeat: true; onTriggered: root.refresh() }
  Timer { id: noticeTimer; interval: 4500; onTriggered: root.notice = "" }
  Timer {
    id: captureDelay
    interval: 300
    onTriggered: {
      captureProcess.command = ["env", "OMARCHY_SCREENSHOT_DIR=" + root.directory,
        "omarchy", "capture", "screenshot", ["region", "fullscreen", "windows"][root.mode], "save"]
      captureProcess.running = true
    }
  }
  Process {
    id: catalogProcess
    stdout: StdioCollector { onStreamFinished: root.loadCatalog(text) }
    stderr: StdioCollector { onStreamFinished: if (text.trim()) root.showNotice(text.trim(), true) }
    onExited: (exitCode, exitStatus) => { if (exitCode !== 0) root.showNotice("No se pudo iniciar el catálogo Delphi", true) }
  }
  Process {
    id: captureProcess
    stdout: StdioCollector { onStreamFinished: root.captureResult = text.trim() }
    stderr: StdioCollector { onStreamFinished: root.captureError = text.trim() }
    onExited: (exitCode, exitStatus) => {
      root.open()
      root.showNotice(exitCode !== 0 ? "La captura no se completó. " + root.captureError : root.captureResult ? "Captura guardada. Ya puedes arrastrarla." : "Captura cancelada", exitCode !== 0)
    }
  }
  Process {
    id: actionProcess
    stderr: StdioCollector { onStreamFinished: if (text.trim()) root.showNotice(text.trim(), true) }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) root.showNotice("No se pudo completar la operación", true)
      root.refresh()
    }
  }

  PanelWindow {
    id: gallery
    visible: false
    screen: root.QsWindow.window ? root.QsWindow.window.screen : Quickshell.screens[0]
    implicitWidth: Math.min(1090, screen.width - 70)
    implicitHeight: Math.min(760, screen.height - 100)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "purodelphi.captura"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    onVisibleChanged: if (visible) { reveal.restart(); surface.forceActiveFocus() }

    Rectangle {
      id: surface
      anchors.fill: parent
      color: "#101724"
      radius: 20
      clip: true
      border.color: "#38465d"
      border.width: 1
      focus: true
      Keys.onEscapePressed: root.close()
      opacity: revealProgress
      scale: 0.975 + revealProgress * 0.025
      property real revealProgress: 0
      SequentialAnimation {
        id: dismiss
        NumberAnimation { target: surface; property: "revealProgress"; to: 0; duration: 180; easing.type: Easing.InCubic }
        ScriptAction { script: gallery.visible = false }
      }
      NumberAnimation { id: reveal; target: surface; property: "revealProgress"; from: 0; to: 1; duration: 360; easing.type: Easing.OutCubic }

      Rectangle {
        id: sidebar
        width: 178
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: "#0c121e"
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#222d40" }
        Column {
          anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22; topMargin: 36 }
          spacing: 12
          Rectangle {
            width: 43; height: 43; radius: 14
            gradient: Gradient { GradientStop { position: 0; color: "#ffd5b7" } GradientStop { position: 1; color: "#e89471" } }
            Text { anchors.centerIn: parent; text: "󰄀"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; color: "#28212a" }
          }
          Text { text: "captura"; color: "#edf2fc"; font.family: "Inter"; font.pixelSize: 25; font.weight: Font.Bold; font.letterSpacing: -0.8 }
          Text { text: "Un instante.\nSiempre a mano."; color: "#8391aa"; font.family: "Inter"; font.pixelSize: 11; lineHeight: 1.5 }
          Item { width: 1; height: 18 }
          Rectangle {
            width: 134; height: 41; radius: 11; color: "#28303d"
            Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
            text: "Tu galería"; color: "#f5c4a7"; font.pixelSize: 12; font.weight: Font.DemiBold }
            Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
            text: root.captureCount; color: "#f5c4a7"; font.pixelSize: 11 }
          }
        }
        Column {
          anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 22; bottomMargin: 26 }
          spacing: 11
          Text { text: "GUARDADAS EN"; font.pixelSize: 9; font.letterSpacing: 1.3; font.weight: Font.DemiBold; color: "#71819c" }
          Text { width: parent.width; text: "Imágenes / Capturas"; wrapMode: Text.Wrap; font.pixelSize: 11; color: "#c3cee0" }
          Text { text: (root.totalBytes / 1048576).toFixed(1) + " MB · hasta 200 imágenes"; font.pixelSize: 9; color: "#7f90aa" }
          ActionButton { text: "Abrir carpeta ↗"; compact: true; onClicked: root.action("folder") }
          Item { width: 1; height: 17 }
          Rectangle { width: 134; height: 1; color: "#263044" }
          Text { text: "CATÁLOGO DELPHI"; font.pixelSize: 8; font.letterSpacing: 1.3; color: "#77cbbb" }
          Text { text: "Hecho para Omarchy"; font.pixelSize: 9; color: "#7d8ba4" }
        }
      }

      Item {
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 30 }
        transform: Translate { y: (1 - surface.revealProgress) * 16 }
        Column {
          id: header
          anchors { left: parent.left; right: parent.right; top: parent.top }
          spacing: 12
          Text { text: "TU ESCRITORIO, EN IMÁGENES"; color: "#f5b18b"; font.family: "Inter"; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold }
          Text { text: "Guarda el instante.\nLlévalo donde quieras."; color: "#eef3fb"; font.family: "Inter"; font.pixelSize: 30; font.letterSpacing: -1; font.weight: Font.DemiBold; lineHeight: 1.1 }
          Text { text: "Captura, encuentra y arrastra tus imágenes a Pinta o a otra aplicación."; color: "#95a4bd"; font.family: "Inter"; font.pixelSize: 11 }
          Item { width: 1; height: 4 }
          Item {
            width: parent.width; height: 48
            Rectangle {
              id: modes
              width: 294; height: 44; radius: 12; color: "#192334"; border.color: "#2b374b"
              Rectangle {
                x: 4 + root.mode * 96; y: 4; width: 94; height: 36; radius: 9; color: "#354156"
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
              }
              Repeater {
                model: ["Región", "Pantalla", "Ventana"]
                delegate: Item {
                  required property int index
                  required property string modelData
                  x: 4 + index * 96; width: 94; height: 44
                  Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 11; font.weight: root.mode === index ? Font.DemiBold : Font.Normal; color: root.mode === index ? "#f3f5fb" : "#92a1b9" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = index }
                }
              }
            }
            ActionButton {
              anchors.right: parent.right
              text: root.capturing ? "Preparando…" : "+  Nueva captura"
              primary: true
              enabled: !root.capturing
              onClicked: root.capture()
            }
          }
          Item { width: 1; height: 2 }
          Row {
            spacing: 8
            Rectangle { width: 5; height: 5; radius: 3; color: "#77cbbb"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Arrastra una miniatura fuera de esta ventana para compartir el archivo."; color: "#92a7bd"; font.pixelSize: 10 }
          }
        }

        Item {
          id: galleryHeading
          anchors { top: header.bottom; topMargin: 24; left: parent.left; right: parent.right }
          height: 34
          Text { text: "Tus capturas"; anchors.verticalCenter: parent.verticalCenter; color: "#e6edf9"; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.DemiBold }
          Rectangle {
            width: 185; height: 30; radius: 9; color: "#192334"; border.color: "#2b374b"; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            TextInput {
              id: search
              anchors { fill: parent; margins: 8 }
              color: "#e6edf9"; font.pixelSize: 11; selectByMouse: true; clip: true
              onTextChanged: { root.filter = text; var saved = root.lastCatalog; root.lastCatalog = ""; if (saved) root.loadCatalog(saved) }
              Text { visible: !search.text && !search.activeFocus; text: "Buscar por nombre…"; color: "#7b8ca8"; font.pixelSize: 10 }
            }
          }
        }

        GridView {
          id: grid
          anchors { top: galleryHeading.bottom; topMargin: 9; bottom: footer.top; bottomMargin: 10; left: parent.left; right: parent.right }
          clip: true
          model: captures
          cellWidth: width / (width > 740 ? 3 : 2)
          cellHeight: 208
          boundsBehavior: Flickable.StopAtBounds
          cacheBuffer: 200
          maximumFlickVelocity: 2200
          delegate: CaptureTile {
            required property int index
            required property var model
            width: grid.cellWidth; height: grid.cellHeight
            imageData: model
            position: index
            selected: root.selectedPath === model.path
            onChoose: root.selectedPath = model.path
            onOpenImage: root.action("pinta", model.path)
            onCopyImage: root.action("copy", model.path)
            onTrashImage: root.action("trash", model.path)
            onDragFinished: action => { if (action !== Qt.IgnoreAction) root.showNotice("Archivo compartido. El original sigue en tu galería.", false) }
          }
          displaced: Transition { NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic } }
          Rectangle {
            anchors.fill: parent
            visible: captures.count === 0
            radius: 16
            color: "#151f2f"
            border.color: "#2a374d"
            Column {
              anchors.centerIn: parent
              spacing: 14
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰄀"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 50; color: "#f5af88" }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.filter ? "No hay coincidencias" : "Tu próxima idea empieza con una captura"; color: "#e7edf8"; font.pixelSize: 15; font.weight: Font.DemiBold }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Elige una región, una ventana o toda la pantalla."; color: "#8c9fb9"; font.pixelSize: 11 }
              ActionButton { anchors.horizontalCenter: parent.horizontalCenter; text: "+  Hacer mi primera captura"; primary: true; onClicked: root.capture() }
            }
          }
        }

        Item {
          id: footer
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: 28
          Text { anchors.verticalCenter: parent.verticalCenter; text: "PNG originales · Solo en tu equipo"; color: "#7f92af"; font.pixelSize: 10 }
          Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            ActionButton { text: "Actualizar"; compact: true; onClicked: root.refresh() }
            ActionButton { text: "A la papelera"; compact: true; enabled: !!root.selectedPath; onClicked: { root.action("trash", root.selectedPath); root.selectedPath = "" } }
          }
        }
      }

      Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 75 }
        width: Math.min(parent.width - 80, toastText.implicitWidth + 40)
        height: 44; radius: 13
        color: root.noticeError ? "#773646" : "#2d514e"
        border.color: root.noticeError ? "#de8995" : "#74b6a6"
        opacity: root.notice ? 1 : 0
        transform: Translate { y: root.notice ? 0 : 12; Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Text { id: toastText; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 25); text: root.notice; elide: Text.ElideRight; color: "#f1f7f6"; font.pixelSize: 11 }
      }
    }
  }
}
