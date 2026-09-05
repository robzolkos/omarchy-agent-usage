import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "robzolkos.agent-usage"
  ipcTarget: "robzolkos.agent-usage"
  manageIpc: false

  property double nowMs: Date.now()
  readonly property color foreground: Color.popups.text
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool alarming: Model.behindPace(service.claude.weekly, nowMs)
    || Model.behindPace(service.codex.weekly, nowMs)

  implicitWidth: usageButton.implicitWidth
  implicitHeight: usageButton.implicitHeight

  function refresh() {
    nowMs = Date.now()
    service.refresh()
  }

  onOpenedChanged: if (opened) {
    nowMs = Date.now()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: root.nowMs = Date.now()
  }

  Service {
    id: service
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string {
      return JSON.stringify({
        refreshing: service.refreshing,
        claude: root.providerStatus(service.claude),
        codex: root.providerStatus(service.codex),
        error: service.lastError
      })
    }
  }

  function providerStatus(provider) {
    var weekly = provider ? provider.weekly : null
    return {
      remaining: weekly ? weekly.remaining : null,
      resetsAt: weekly ? new Date(weekly.resetMs).toISOString() : "",
      behindPace: Model.behindPace(weekly, nowMs),
      status: provider ? provider.status : ""
    }
  }

  WidgetButton {
    id: usageButton
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : barContent.implicitWidth + Style.space(16)
    tooltipText: "Weekly allowance used · click for details"
    active: root.alarming
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(12)

      ProviderChip {
        provider: service.claude
        iconSource: Qt.resolvedUrl("claude.svg")
        tintIcon: false
      }

      Rectangle {
        width: 1
        height: Style.space(13)
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.darker(root.barForeground, 1.55)
        opacity: 0.65
      }

      ProviderChip {
        provider: service.codex
        iconSource: Qt.resolvedUrl("codex.svg")
        tintIcon: true
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: usageButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(410))
    contentHeight: panel.fittedContentHeight(panelContent.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.refresh()
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh() }

      Column {
        id: panelContent
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          width: parent.width

          Text {
            Layout.fillWidth: true
            text: "AGENT USAGE"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: service.refreshing ? "Refreshing…" : "R to refresh"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        ProviderCard {
          width: parent.width
          provider: service.claude
          iconSource: Qt.resolvedUrl("claude.svg")
          tintIcon: false
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        ProviderCard {
          width: parent.width
          provider: service.codex
          iconSource: Qt.resolvedUrl("codex.svg")
          tintIcon: true
        }

        Text {
          visible: service.lastError !== ""
          width: parent.width
          text: service.lastError
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  component ProviderIcon: Item {
    id: providerIcon
    property url source: ""
    property bool tinted: false
    property color color: root.foreground
    property real iconSize: Style.space(12)
    width: iconSize
    height: iconSize

    Image {
      id: plainIcon
      anchors.fill: parent
      source: providerIcon.source
      visible: !providerIcon.tinted
      sourceSize.width: providerIcon.iconSize * 2
      sourceSize.height: providerIcon.iconSize * 2
      fillMode: Image.PreserveAspectFit
    }

    Image {
      id: maskIcon
      anchors.fill: parent
      source: providerIcon.source
      visible: false
      sourceSize.width: providerIcon.iconSize * 2
      sourceSize.height: providerIcon.iconSize * 2
      fillMode: Image.PreserveAspectFit
    }

    MultiEffect {
      anchors.fill: parent
      source: maskIcon
      visible: providerIcon.tinted
      colorization: 1.0
      colorizationColor: providerIcon.color
    }
  }

  component ProviderChip: Row {
    id: chip
    required property var provider
    property url iconSource: ""
    property bool tintIcon: false
    readonly property var weekly: provider ? provider.weekly : null
    readonly property bool behind: Model.behindPace(weekly, root.nowMs)
    spacing: Style.space(5)
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    ProviderIcon {
      anchors.verticalCenter: parent.verticalCenter
      source: chip.iconSource
      tinted: chip.tintIcon
      color: chip.behind ? root.urgent : root.barForeground
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: chip.provider.id === "claude" ? "Claude" : "Codex"
      color: chip.behind ? root.urgent : root.barForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: chip.weekly
        ? Model.percent(chip.weekly.used) + " · " + Model.countdown(chip.weekly.resetMs, root.nowMs)
        : "—"
      color: chip.behind ? root.urgent : root.barForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  component ProviderCard: Column {
    id: card
    required property var provider
    property url iconSource: ""
    property bool tintIcon: false
    readonly property var weekly: provider ? provider.weekly : null
    readonly property bool behind: Model.behindPace(weekly, root.nowMs)
    spacing: Style.space(8)

    Row {
      width: parent.width
      spacing: Style.space(9)

      ProviderIcon {
        anchors.verticalCenter: parent.verticalCenter
        source: card.iconSource
        tinted: card.tintIcon
        color: card.behind ? root.urgent : root.foreground
        iconSize: Style.space(18)
      }

      Column {
        width: parent.width - x
        spacing: Style.space(2)

        Text {
          text: card.provider.id === "claude" ? "Claude" : "Codex"
          color: card.behind ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          text: card.weekly
            ? Model.percent(card.weekly.used) + " used · resets in " + Model.countdown(card.weekly.resetMs, root.nowMs)
            : (card.provider.status || "Weekly limit unavailable")
          color: card.behind ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }

    Rectangle {
      visible: !!card.weekly
      width: parent.width
      height: Style.space(5)
      radius: height / 2
      color: Qt.darker(root.foreground, 2.5)

      Rectangle {
        width: parent.width * (card.weekly ? card.weekly.used : 0)
        height: parent.height
        radius: parent.radius
        color: card.behind ? root.urgent : root.foreground
      }
    }

    RowLayout {
      visible: !!card.weekly
      width: parent.width

      Text {
        Layout.fillWidth: true
        text: Model.paceText(card.weekly, root.nowMs)
        color: card.behind ? root.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        text: "Expected " + Model.percent(1 - Model.expectedRemaining(card.weekly, root.nowMs)) + " used"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Column {
      visible: card.provider && Array.isArray(card.provider.recentDays) && card.provider.recentDays.length > 0
      width: parent.width
      spacing: Style.space(5)

      Text {
        text: "LAST 7 DAYS · " + Model.tokenCount(Model.recentTotal(card.provider.recentDays)) + " TOKENS"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Row {
        id: dailyChart
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: card.provider.recentDays

          delegate: Column {
            required property var modelData
            readonly property real tokens: Model.dayTokens(modelData)
            readonly property real peak: Math.max(1, Model.recentPeak(card.provider.recentDays))
            width: (dailyChart.width - dailyChart.spacing * 6) / 7
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: Model.tokenCount(parent.tokens)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }

            Item {
              width: parent.width
              height: Style.space(28)

              Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(Style.space(8), parent.width - Style.space(8))
                height: parent.parent.tokens > 0 ? Math.max(1, parent.height * parent.parent.tokens / parent.parent.peak) : 0
                radius: Style.space(2)
                color: card.behind ? root.urgent : root.foreground
                opacity: 0.72
              }
            }

            Text {
              width: parent.width
              text: Model.dayLabel(parent.modelData.date)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }
      }
    }

    Repeater {
      model: card.provider && Array.isArray(card.provider.limits) ? card.provider.limits : []
      delegate: RowLayout {
        required property var modelData
        width: card.width
        visible: String(modelData.label || "").toLowerCase().indexOf("weekly") !== 0

        Text {
          Layout.fillWidth: true
          text: modelData.label
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          text: Model.percent(modelData.used) + " used · " + Model.countdown(modelData.resetMs, root.nowMs)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
