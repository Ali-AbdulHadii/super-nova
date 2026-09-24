pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Assigned only when the set of names changes, so a list refresh updates rows
    // in place instead of rebuilding them (which would close open menus)
    property list<string> schemeNames
    readonly property bool isDynamic: Colours.scheme === "dynamic"
    readonly property bool smart: GlobalConfig.services.smartScheme

    readonly property MenuItem lightItem: MenuItem {
        text: Tr.tr("Light")
        icon: "light_mode"
        value: "light"
    }
    readonly property MenuItem darkItem: MenuItem {
        text: Tr.tr("Dark")
        icon: "dark_mode"
        value: "dark"
    }
    readonly property MenuItem autoItem: MenuItem {
        text: Tr.tr("Auto")
        icon: "brightness_auto"
        value: "auto"
    }
    readonly property list<MenuItem> modeItems: {
        const items = [];
        if (Colours.modes.includes("light"))
            items.push(lightItem);
        if (Colours.modes.includes("dark"))
            items.push(darkItem);
        if (isDynamic)
            items.push(autoItem);
        return items;
    }
    readonly property MenuItem modeActive: isDynamic && smart ? autoItem : (Colours.currentLight ? lightItem : darkItem)

    function schemeLabel(name: string): string {
        if (name === "dynamic")
            return Tr.tr("From wallpaper");
        const names = {
            caelestia: "Caelestia",
            catppuccin: "Catppuccin",
            darkgreen: "Dark Green",
            dracula: "Dracula",
            everblush: "Everblush",
            everforest: "Everforest",
            gruvbox: "Gruvbox",
            nord: "Nord",
            oldworld: "Oldworld",
            onedark: "One Dark",
            rosepine: "Rosé Pine",
            shadotheme: "Shadotheme",
            solarized: "Solarized",
            tokyonight: "Tokyo Night"
        };
        return names[name] ?? name.charAt(0).toUpperCase() + name.slice(1);
    }

    function updateNames(): void {
        const keys = Object.keys(Schemes.byName);
        const rest = keys.filter(k => k !== "dynamic").sort();
        const next = keys.includes("dynamic") ? ["dynamic", ...rest] : rest;
        if (next.join() !== schemeNames.join())
            schemeNames = next;
    }

    // Only names and flavours the CLI itself listed are accepted
    function applyScheme(name: string, flavour: string): void {
        const flavours = Schemes.byName[name];
        if (!flavours || !Object.prototype.hasOwnProperty.call(flavours, flavour))
            return;
        if (name === Colours.scheme && flavour === Colours.flavour)
            return;
        // Coming back to dynamic keeps the preset's mode until smart detection re-runs
        Colours.setScheme(name, flavour, name === "dynamic" && Colours.scheme !== "dynamic" && smart);
    }

    // The CLI does not validate variants, so only the known list is accepted
    function applyVariant(variant: string): void {
        if (!M3Variants.list.some(v => v.variant === variant) || variant === Colours.variant)
            return;
        // Auto would overwrite an explicit choice on the next wallpaper change
        if (smart)
            GlobalConfig.services.smartScheme = false;
        Colours.setVariant(variant);
    }

    function applyMode(item: MenuItem): void {
        if (item === autoItem) {
            if (!isDynamic)
                return;
            GlobalConfig.services.smartScheme = true;
            Colours.rederive();
            return;
        }

        const mode = item?.value ?? "";
        if (!Colours.modes.includes(mode))
            return;
        if (isDynamic)
            GlobalConfig.services.smartScheme = false;
        if (mode !== (Colours.currentLight ? "light" : "dark"))
            Colours.setMode(mode);
    }

    title: Tr.tr("Colours")
    isSubPage: true

    onModeActiveChanged: modeRow.active = modeActive
    Component.onCompleted: {
        updateNames();
        modeRow.active = modeActive;
        Schemes.reloadList();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Scheme
        SectionHeader {
            first: true
            text: Tr.tr("Scheme")
        }

        Repeater {
            model: root.schemeNames

            SchemeRow {
                required property string modelData
                required property int index

                name: modelData
                flavours: Schemes.byName[modelData]
                first: index === 0
                last: index === root.schemeNames.length - 1
                label: root.schemeLabel(modelData)
                subtext: modelData === "dynamic" ? Tr.tr("Generated from the current wallpaper") : ""
                onApplied: flavour => root.applyScheme(modelData, flavour)
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: root.schemeNames.length === 0
            first: true
            last: true
            implicitHeight: loadingText.implicitHeight + Tokens.padding.extraLarge * 2

            StyledText {
                id: loadingText

                anchors.centerIn: parent
                text: Tr.tr("Loading colour schemes…")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.body.small
            }
        }

        // Style
        SectionHeader {
            visible: root.isDynamic
            text: Tr.tr("Style")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.extraSmall
            visible: root.isDynamic && root.smart
            text: Tr.tr("Chosen from the wallpaper while mode is Auto. Picking a style turns Auto off.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        Repeater {
            model: root.isDynamic ? M3Variants.list : []

            RowButton {
                required property M3Variants.Variant modelData
                required property int index
                readonly property bool selected: modelData.variant === Colours.variant

                first: index === 0
                last: index === M3Variants.list.length - 1
                icon: modelData.icon
                text: modelData.name
                subtext: modelData.description
                trailingIcon: selected ? "check" : ""
                trailingIconColour: Colours.palette.m3onTertiaryContainer
                color: selected ? Colours.palette.m3tertiaryContainer : Colours.tPalette.m3surfaceContainer
                label.color: selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                iconLabel.color: selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                subLabel.color: selected ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3outline
                onClicked: root.applyVariant(modelData.variant)
            }
        }

        // Mode
        SectionHeader {
            text: Tr.tr("Mode")
        }

        SelectRow {
            id: modeRow

            first: true
            last: true
            label: Tr.tr("Theme mode")
            subtext: {
                if (root.isDynamic && root.smart)
                    return Tr.tr("Follows the wallpaper's brightness");
                if (Colours.modes.length < 2)
                    return Colours.modes.includes("light") ? Tr.tr("This scheme only has a light version") : Tr.tr("This scheme only has a dark version");
                if (!root.isDynamic)
                    return Tr.tr("Auto is only available with the From wallpaper scheme");
                return "";
            }
            disabled: root.modeItems.length < 2
            menuOnTop: true
            menuItems: root.modeItems
            onSelected: item => root.applyMode(item)
        }

        // Transparency
        SectionHeader {
            text: Tr.tr("Transparency")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Transparency")
            // TRANSLATORS: %1/%2 = opacity values from 0 to 1 for the base surface and layered surfaces
            subtext: Tr.tr("Base %1, layers %2").arg(Colours.transparency.base).arg(Colours.transparency.layers)
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        // Previews depend on the current mode, and dynamic on the variant and wallpaper
        Timer {
            id: refreshTimer

            interval: 250
            onTriggered: Schemes.reloadList()
        }

        Connections {
            function onByNameChanged(): void {
                root.updateNames();
            }

            target: Schemes
        }

        Connections {
            function onCurrentLightChanged(): void {
                refreshTimer.restart();
            }

            function onVariantChanged(): void {
                refreshTimer.restart();
            }

            target: Colours
        }

        Connections {
            function onActualCurrentChanged(): void {
                refreshTimer.restart();
            }

            target: Wallpapers
        }
    }
}
