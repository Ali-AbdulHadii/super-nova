pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ConnectedRect {
    id: root

    required property string name
    required property var flavours
    property alias label: label.text
    property alias subtext: subLabel.text
    property string pickedFlavour

    readonly property list<string> flavourNames: Object.keys(flavours ?? {})
    readonly property bool selected: name === Colours.scheme
    readonly property string shownFlavour: selected ? Colours.flavour : (flavourNames.includes(pickedFlavour) ? pickedFlavour : (flavourNames[0] ?? ""))
    readonly property var colours: flavours?.[shownFlavour] ?? ({})
    // The applied scheme reads the live palette, so it follows scheme.json instantly
    readonly property bool live: selected && shownFlavour === Colours.flavour

    signal applied(flavour: string)

    function hex(key: string): color {
        const c = colours[key];
        return c ? `#${c}` : "transparent";
    }

    function flavourText(f: string): string {
        if (name === "dynamic")
            return f === "hard" ? Tr.trCtx("Hard", "colour scheme flavour") : Tr.trCtx("Default", "colour scheme flavour");
        return f.charAt(0).toUpperCase() + f.slice(1);
    }

    // Menu assigns active itself on pick, which would break a declared binding
    function syncActive(): void {
        flavourBtn.active = flavourItems.instances.find(i => i.value === shownFlavour) ?? null; // qmllint disable missing-property
    }

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2
    clip: false
    z: flavourBtn.expanded ? 1 : 0
    color: selected ? Colours.palette.m3tertiaryContainer : Colours.tPalette.m3surfaceContainer

    onShownFlavourChanged: syncActive()
    Component.onCompleted: syncActive()

    StateLayer {
        color: root.selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
        onClicked: root.applied(root.shownFlavour)
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: dots.implicitWidth + Tokens.padding.extraSmall * 2
            implicitHeight: dots.implicitHeight + Tokens.padding.extraSmall * 2
            radius: Tokens.rounding.full
            color: root.live ? Colours.current.m3surface : root.hex("surface")
            border.width: 1
            border.color: Qt.alpha(root.live ? Colours.current.m3outline : root.hex("outline"), 0.5)

            Row {
                id: dots

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                StyledRect {
                    implicitWidth: Tokens.padding.large
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    color: root.live ? Colours.current.m3primary : root.hex("primary")
                }

                StyledRect {
                    implicitWidth: Tokens.padding.large
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    color: root.live ? Colours.current.m3secondary : root.hex("secondary")
                }

                StyledRect {
                    implicitWidth: Tokens.padding.large
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    color: root.live ? Colours.current.m3tertiary : root.hex("tertiary")
                }
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                anchors.left: parent.left
                anchors.right: parent.right

                color: root.selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                id: subLabel

                anchors.left: parent.left
                anchors.right: parent.right

                visible: text
                color: root.selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        SplitButton {
            id: flavourBtn

            // Hidden but kept in the layout, so every row in the group has the same height
            opacity: root.flavourNames.length > 1 ? 1 : 0
            enabled: opacity > 0
            type: SplitButton.Tonal
            menuItems: flavourItems.instances // qmllint disable missing-property
            stateLayer.onClicked: flavourBtn.expanded = !flavourBtn.expanded
            menu.onItemSelected: item => {
                const f = (item as MenuItem)?.value ?? "";
                root.pickedFlavour = f;
                root.applied(f);
            }
        }

        MaterialIcon {
            text: "check"
            color: Colours.palette.m3onTertiaryContainer
            fontStyle: Tokens.font.icon.medium
            opacity: root.selected ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.SlowEffects
                }
            }
        }
    }

    Variants {
        id: flavourItems

        model: root.flavourNames
        onInstancesChanged: root.syncActive()

        MenuItem {
            required property string modelData

            text: root.flavourText(modelData)
            value: modelData
        }
    }
}
