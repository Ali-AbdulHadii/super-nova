pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common

DialogRowButton {
    id: root

    property string current
    property bool monoOnly
    property string query
    property string selectedFamily

    // Noto ships ~240 per-script families nobody picks as a UI font. They stay out
    // of the list until the search asks for them.
    readonly property list<string> notoKept: ["Noto Sans", "Noto Serif", "Noto Sans Mono", "Noto Sans Display", "Noto Serif Display"]
    readonly property list<string> allFamilies: monoOnly ? Fonts.monoFamilies : Fonts.families
    readonly property list<string> families: {
        const q = query.trim().toLowerCase();
        if (q)
            return allFamilies.filter(f => f.toLowerCase().includes(q));
        return allFamilies.filter(f => !f.startsWith("Noto ") || notoKept.includes(f));
    }

    signal picked(family: string)

    // fontconfig matches family names ignoring case and blanks, so the configured
    // "GoogleSansFlex" is the installed "Google Sans Flex".
    function normalise(family: string): string {
        return family.replace(/\s+/g, "").toLowerCase();
    }

    function matchCurrent(): string {
        const n = normalise(current);
        return allFamilies.find(f => normalise(f) === n) ?? "";
    }

    onOpenChanged: {
        if (open) {
            query = "";
            selectedFamily = matchCurrent();
        }
    }
    onAccepted: {
        // The only path from the picker to the config: never write a family the
        // font database does not offer.
        if (Fonts.isInstalled(selectedFamily))
            root.picked(selectedFamily);
    }

    subtext: current
    acceptLabel: Tr.trCtx("Select", "button")
    acceptAllowed: selectedFamily && selectedFamily !== matchCurrent()
    separateContent: true
    horizontalContentMargin: -Tokens.padding.small

    content: Component {
        ColumnLayout {
            spacing: Tokens.spacing.small

            SearchBar {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.padding.large
                Layout.leftMargin: Tokens.padding.small
                Layout.rightMargin: Tokens.padding.small

                placeholderText: Tr.tr("Search fonts")
                font: Tokens.font.body.large
                bg.color: Colours.tPalette.m3surfaceContainerLowest
                bg.border.color: Colours.palette.m3outlineVariant
                searchIcon.fontStyle: Tokens.font.icon.medium
                searchIcon.anchors.leftMargin: Tokens.padding.largeIncreased
                clearIcon.font: Tokens.font.icon.medium
                clearIcon.padding: Tokens.padding.extraSmall
                onTextChanged: root.query = text
                Component.onCompleted: forceActiveFocus()

                Behavior on bg.border.color {
                    CAnim {}
                }
            }

            VerticalFadeListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 0
                bottomMargin: Tokens.padding.large
                model: root.families
                // Each row renders in its own face, so every cached delegate is
                // another font engine. Leave cacheBuffer at the default.
                reuseItems: true

                // The dialog content loads asynchronously, so the view has no
                // geometry until after completion
                Component.onCompleted: Qt.callLater(() => {
                    const idx = root.families.indexOf(root.selectedFamily);
                    if (idx >= 0)
                        list.positionViewAtIndex(idx, ListView.Center);
                })

                delegate: StyledRect {
                    id: item

                    required property string modelData
                    readonly property bool selected: root.selectedFamily === modelData

                    anchors.left: ListView.view.contentItem.left
                    anchors.right: ListView.view.contentItem.right
                    anchors.margins: 1 // Gets cut off for some reason without this
                    implicitHeight: label.implicitHeight + Tokens.padding.medium * 2

                    radius: stateLayer.pressed ? Tokens.rounding.extraSmall : selected ? Tokens.rounding.largeIncreased : Tokens.rounding.medium
                    color: Qt.alpha(Colours.palette.m3tertiaryContainer, selected ? 1 : 0)

                    Behavior on radius {
                        Anim {
                            type: Anim.SlowEffects
                        }
                    }

                    StateLayer {
                        id: stateLayer

                        onClicked: root.selectedFamily = item.modelData
                    }

                    StyledText {
                        id: label

                        anchors.left: parent.left
                        anchors.right: item.selected ? checkIcon.left : parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.large
                        anchors.rightMargin: item.selected ? Tokens.spacing.medium : anchors.margins

                        text: item.modelData
                        font: Tokens.font.body.builders.large.family(item.modelData).build()
                        color: item.selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    MaterialIcon {
                        id: checkIcon

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.large

                        text: "check"
                        color: Colours.palette.m3onTertiaryContainer
                        fontStyle: Tokens.font.icon.medium
                        opacity: item.selected ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.SlowEffects
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Tokens.padding.large

                visible: root.families.length === 0
                text: Tr.tr("No fonts match your search")
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
