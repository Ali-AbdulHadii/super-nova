pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
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

    readonly property MenuItem standardItem: MenuItem {
        text: Tr.tr("Standard")
        icon: "rectangle"
    }
    readonly property MenuItem glassItem: MenuItem {
        text: Tr.tr("Liquid Glass")
        icon: "water_drop"
    }
    readonly property MenuItem realisticItem: MenuItem {
        text: Tr.tr("Realistic glass")
        icon: "lens_blur"
    }
    readonly property MenuItem styleActive: Colours.glass.realistic ? realisticItem : (Colours.glass.enabled ? glassItem : standardItem)

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
    onStyleActiveChanged: styleRow.active = styleActive
    Component.onCompleted: {
        styleRow.active = styleActive;
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

        // Surface style
        SectionHeader {
            text: Tr.tr("Surface style")
        }

        SelectRow {
            id: styleRow

            first: true
            last: !Colours.glass.enabled
            label: Tr.tr("Style")
            subtext: Colours.glass.realistic ? Tr.tr("Bends the wallpaper; panels don't show windows behind them") : Tr.tr("How the bar and panels are drawn")
            menuOnTop: true
            menuItems: [root.standardItem, root.glassItem, root.realisticItem]
            onSelected: item => {
                const glass = GlobalConfig.appearance.glass;
                const enabled = item !== root.standardItem;
                const realistic = item === root.realisticItem;
                if (enabled !== glass.enabled)
                    glass.enabled = enabled;
                if (realistic !== glass.realistic)
                    glass.realistic = realistic;
            }
        }

        SliderRow {
            visible: Colours.glass.enabled
            icon: "opacity"
            label: Tr.tr("Glass tint")
            valueLabel: Strings.percentOne(value)
            value: Colours.glass.tint
            onMoved: v => {
                const tint = Math.max(0.1, Math.min(0.8, v));
                if (tint !== GlobalConfig.appearance.glass.tint)
                    GlobalConfig.appearance.glass.tint = tint;
            }
        }

        SliderRow {
            visible: Colours.glass.enabled
            last: !Colours.glass.realistic
            icon: "flare"
            label: Tr.tr("Highlight")
            valueLabel: Strings.percentOne(value)
            value: Colours.glass.highlight
            onMoved: v => {
                const highlight = Math.max(0, Math.min(1, v));
                if (highlight !== GlobalConfig.appearance.glass.highlight)
                    GlobalConfig.appearance.glass.highlight = highlight;
            }
        }

        SliderRow {
            visible: Colours.glass.realistic
            icon: "lens"
            label: Tr.tr("Refraction")
            valueLabel: Strings.percentOne(value)
            value: Colours.glass.refraction
            onMoved: v => {
                const refraction = Math.max(0, Math.min(1, v));
                if (refraction !== GlobalConfig.appearance.glass.refraction)
                    GlobalConfig.appearance.glass.refraction = refraction;
            }
        }

        SliderRow {
            visible: Colours.glass.realistic
            last: true
            icon: "gradient"
            label: Tr.tr("Colour fringing")
            valueLabel: Strings.percentOne(value)
            value: Colours.glass.dispersion
            onMoved: v => {
                const dispersion = Math.max(0, Math.min(1, v));
                if (dispersion !== GlobalConfig.appearance.glass.dispersion)
                    GlobalConfig.appearance.glass.dispersion = dispersion;
            }
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
            subtext: Colours.glass.enabled ? Tr.tr("Included in Liquid Glass") : Tr.tr("Base %1, layers %2").arg(Colours.transparency.base).arg(Colours.transparency.layers)
            checked: Colours.transparency.enabled
            disabled: Colours.glass.enabled
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
