pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    // Writes go to the global layer, never to a per-monitor overlay, so a font
    // picked here applies on every screen.
    function setInterface(family: string): void {
        const font = GlobalConfig.appearance.font;
        font.headline.family = family;
        font.title.family = family;
        font.body.family = family;
        font.label.family = family;
    }

    title: Tr.tr("Fonts")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        FontSelectButton {
            // DialogRowButton defaults to last: true, so every row but the bottom
            // one has to say otherwise or the group reads as separate pills.
            first: true
            last: false
            rootParent: root.flickable
            icon: "text_fields"
            label: Tr.tr("Interface")
            header: Tr.tr("Interface font")
            current: Config.appearance.font.body.family
            onPicked: family => root.setInterface(family)
        }

        FontSelectButton {
            last: false
            rootParent: root.flickable
            icon: "code"
            label: Tr.tr("Monospace")
            header: Tr.tr("Monospace font")
            monoOnly: true
            current: Config.appearance.font.mono.family
            onPicked: family => GlobalConfig.appearance.font.mono.family = family
        }

        FontSelectButton {
            last: true
            rootParent: root.flickable
            icon: "schedule"
            label: Tr.tr("Clock")
            header: Tr.tr("Clock font")
            current: Config.appearance.font.clock
            onPicked: family => GlobalConfig.appearance.font.clock = family
        }
    }
}
