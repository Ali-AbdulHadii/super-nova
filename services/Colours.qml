pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Images
import qs.services
import qs.utils

Singleton {
    id: root

    property bool showPreview
    property string scheme
    property string flavour
    property string variant
    property list<string> modes: ["light", "dark"]
    readonly property bool light: showPreview ? previewLight : currentLight
    property bool currentLight
    property bool previewLight
    readonly property M3Palette palette: showPreview ? preview : current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3Palette current: M3Palette {}
    readonly property M3Palette preview: M3Palette {}
    readonly property Transparency transparency: Transparency {}
    readonly property Glass glass: Glass {}
    readonly property alias wallLuminance: analyser.luminance

    property var cmdQueue: []
    property bool modesPending
    property bool cooldownPending
    property real lastBaseTransparency

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);

        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base) * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;

        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    // Apple glass keeps inner cards light and see-through, like Apple's controls,
    // rather than the scheme's dark container slabs
    function card(c: color): color {
        if (!glass.apple)
            return layer(c);
        return Qt.alpha(Qt.tint(c, Qt.rgba(1, 1, 1, light ? 0.5 : 0.18)), light ? 0.45 : 0.2);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function load(data: string, isPreview: bool): void {
        const colours = isPreview ? preview : current;
        const scheme = JSON.parse(data);

        if (!isPreview) {
            const changed = scheme.name !== root.scheme || scheme.flavour !== root.flavour;
            root.scheme = scheme.name;
            flavour = scheme.flavour;
            currentLight = scheme.mode === "light";
            root.variant = scheme.variant ?? "";
            if (changed)
                root.refreshModes();
        } else {
            previewLight = scheme.mode === "light";
        }

        for (const [name, colour] of Object.entries(scheme.colours)) {
            const propName = name.startsWith("term") ? name : `m3${name}`;
            if (colours.hasOwnProperty(propName))
                colours[propName] = `#${colour}`;
        }
    }

    // Scheme changes run one at a time: each CLI call rewrites scheme.json, so
    // overlapping calls (e.g. set scheme, then re-derive from the wallpaper) race.
    function run(argv: list<string>): void {
        cmdQueue.push(argv);
        if (!cmdProc.running)
            runNext();
    }

    function runNext(): void {
        const next = cmdQueue.shift();
        if (next)
            cmdProc.exec(next);
    }

    // The modes the current scheme and flavour actually ship. The CLI hard-codes
    // light + dark for dynamic, so it isn't asked.
    function refreshModes(): void {
        if (scheme === "dynamic") {
            modes = ["light", "dark"];
        } else if (modesProc.running) {
            modesPending = true;
        } else {
            modesProc.running = true;
        }
    }

    function setMode(mode: string): void {
        if (mode !== "light" && mode !== "dark")
            return;
        run(["caelestia", "scheme", "set", "--notify", "-m", mode]);
    }

    function setScheme(name: string, flavour: string, rederive: bool): void {
        run(["caelestia", "scheme", "set", "--notify", "-n", name, "-f", flavour]);
        if (rederive)
            root.rederive();
    }

    // The CLI accepts any string here, so callers must validate the variant
    function setVariant(variant: string): void {
        run(["caelestia", "scheme", "set", "-v", variant]);
    }

    // Re-runs smart scheme detection for the current wallpaper (no --no-smart on purpose)
    function rederive(): void {
        if (Wallpapers.actualCurrent)
            run(["caelestia", "wallpaper", "-f", Wallpapers.actualCurrent]);
    }

    function reloadHyprRules(): void {
        // Realistic glass paints an opaque body from the wallpaper, so compositor blur
        // behind it would be wasted work
        const blurBehind = transparency.enabled && !glass.opaqueBody;
        let rule, trEnabled;
        if (Hypr.usingLua) {
            rule = `eval hl.layer_rule({ match = { namespace = "caelestia-drawers" }, %1 = %2 })`;
            trEnabled = blurBehind;
        } else {
            rule = "keyword layerrule %1 %2, match:namespace caelestia-drawers";
            trEnabled = blurBehind ? 1 : 0;
        }
        // Glass blurs only the tinted body: the soft shadow around it stays below the cutoff.
        // Apple glass has no shadow and a nearly clear body, so its cutoff sits just above 0.
        let ignoreAlpha = glass.enabled ? glass.tint - 0.05 : transparency.base - 0.03;
        if (glass.apple)
            ignoreAlpha = glass.refracting ? glass.pluginIgnoreAlpha : 0.01;
        const msgs = [rule.arg("blur").arg(trEnabled), rule.arg("ignore_alpha").arg(Math.max(0, ignoreAlpha))];

        // hyprliquid refracts the windows behind Apple glass. The rule is named so each
        // reload replaces it, and it is only sent while the plugin is loaded, since
        // Hyprland rejects rule keys it doesn't know.
        if (Hypr.usingLua && glass.pluginPresent)
            msgs.push(`eval hl.layer_rule({ name = "caelestia-glass", enabled = ${glass.refracting}, match = { namespace = "caelestia-drawers" }, ["hyprliquid:effect"] = "liquid_glass", ["hyprliquid:corner_radius"] = ${glass.pluginCornerRadius}, ["hyprliquid:vdf_map_mode"] = ${glass.pluginVdfMode}, ["hyprliquid:vdf_map_update_policy"] = "${glass.pluginVdfPolicy}", ["hyprliquid:highlight_style"] = ${glass.pluginHighlight}, ["hyprliquid:glass_ior"] = ${glass.pluginIor.toFixed(4)}, ["hyprliquid:glass_dispersion"] = ${glass.dispersion > 0} })`);

        Hypr.extras.batchMessage(msgs);
    }

    function refreshGlassPlugin(): void {
        glassPluginProc.running = true;
    }

    function requestReloadHyprRules(): void {
        if (cooldownTimer.running) {
            root.cooldownPending = true;
        } else {
            root.reloadHyprRules();
            cooldownTimer.restart();
        }
    }

    Component.onCompleted: {
        root.requestReloadHyprRules();
        root.refreshGlassPlugin();
    }

    Connections {
        function onConfigReloaded(): void {
            root.reloadHyprRules();
            root.refreshGlassPlugin();
        }

        target: Hypr
    }

    FileView {
        path: `${Paths.state}/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text(), false)
    }

    Process {
        id: cmdProc

        onRunningChanged: {
            if (!running)
                root.runNext();
        }
    }

    Process {
        id: modesProc

        command: ["caelestia", "scheme", "list", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const modes = text.trim().split("\n").filter(m => m === "light" || m === "dark");
                root.modes = modes.length ? modes : ["light", "dark"];
                if (root.modesPending) {
                    root.modesPending = false;
                    root.refreshModes();
                }
            }
        }
    }

    Process {
        id: glassPluginProc

        command: ["hyprctl", "plugin", "list", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let present = false;
                try {
                    present = JSON.parse(text).some(p => String(p?.name ?? "").toLowerCase().includes("hyprliquid"));
                } catch (e) {}
                root.glass.pluginPresent = present;
            }
        }
    }

    ImageAnalyser {
        id: analyser

        source: Wallpapers.current
    }

    Timer {
        id: cooldownTimer

        interval: 30
        onTriggered: {
            if (root.cooldownPending) {
                root.cooldownPending = false;
                root.reloadHyprRules();
                restart();
            }
        }
    }

    Timer {
        id: cAnimCompleteTimer

        interval: Tokens.anim.durations.expressiveSlowEffects
        onTriggered: root.requestReloadHyprRules()
    }

    // Liquid Glass surface style for the bar and drawers (see GlassEffect.qml)
    component Glass: QtObject {
        readonly property bool enabled: Tokens.glass.enabled
        readonly property real tint: Math.max(0.1, Math.min(0.8, Tokens.glass.tint))
        readonly property real highlight: Math.max(0, Math.min(1, Tokens.glass.highlight))
        readonly property bool realistic: enabled && Tokens.glass.realistic && !Tokens.glass.apple
        readonly property bool apple: enabled && Tokens.glass.apple
        readonly property real refraction: Math.max(0, Math.min(1, Tokens.glass.refraction))
        readonly property real dispersion: Math.max(0, Math.min(1, Tokens.glass.dispersion))
        // Realistic glass falls back to the see-through kind when there is no wallpaper
        readonly property bool opaqueBody: realistic && GlobalConfig.background.wallpaperEnabled

        // The hyprliquid Hyprland plugin, if loaded, refracts what is behind Apple glass
        property bool pluginPresent
        readonly property bool refracting: apple && pluginPresent
        // Tuned against the drawers surface: one radius for every shape, as the plugin
        // requires (panels are 28px, the frame 25px). Mode 2 is for shapes that meet.
        readonly property int pluginCornerRadius: 28
        readonly property int pluginVdfMode: 2
        // "onchange" halves the plugin's idle GPU cost against "always", with no visible
        // lag on the drawers' slide (measured on the RTX 5080)
        readonly property string pluginVdfPolicy: "onchange"
        readonly property int pluginHighlight: 0
        readonly property real pluginIgnoreAlpha: 0.01
        // Refraction 0-1 maps onto a glass index of refraction of 1.0-1.07
        readonly property real pluginIor: 1 + refraction * 0.07

        onEnabledChanged: root.requestReloadHyprRules()
        onTintChanged: root.requestReloadHyprRules()
        onOpaqueBodyChanged: root.requestReloadHyprRules()
        onRefractingChanged: root.requestReloadHyprRules()
        onPluginIorChanged: {
            if (refracting)
                root.requestReloadHyprRules();
        }
        onDispersionChanged: {
            if (refracting)
                root.requestReloadHyprRules();
        }
    }

    component Transparency: QtObject {
        // Glass implies transparency, so cards inside glass panels aren't opaque slabs
        readonly property bool enabled: Tokens.transparency.enabled || root.glass.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Math.max(0, Math.min(1, Tokens.transparency.layers))

        onEnabledChanged: {
            if (enabled)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
        }
        onBaseChanged: {
            if (root.lastBaseTransparency > base)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
            root.lastBaseTransparency = base;
        }
    }

    component M3TPalette: QtObject {
        readonly property color m3primary_paletteKeyColor: root.layer(root.palette.m3primary_paletteKeyColor)
        readonly property color m3secondary_paletteKeyColor: root.layer(root.palette.m3secondary_paletteKeyColor)
        readonly property color m3tertiary_paletteKeyColor: root.layer(root.palette.m3tertiary_paletteKeyColor)
        readonly property color m3neutral_paletteKeyColor: root.layer(root.palette.m3neutral_paletteKeyColor)
        readonly property color m3neutral_variant_paletteKeyColor: root.layer(root.palette.m3neutral_variant_paletteKeyColor)
        readonly property color m3background: root.layer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.layer(root.palette.m3onBackground)
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.card(root.palette.m3surfaceContainerLowest)
        readonly property color m3surfaceContainerLow: root.card(root.palette.m3surfaceContainerLow)
        readonly property color m3surfaceContainer: root.card(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.card(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.card(root.palette.m3surfaceContainerHighest)
        readonly property color m3onSurface: root.layer(root.palette.m3onSurface)
        readonly property color m3surfaceVariant: root.layer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.layer(root.palette.m3onSurfaceVariant)
        readonly property color m3inverseSurface: root.layer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.layer(root.palette.m3inverseOnSurface)
        readonly property color m3outline: root.layer(root.palette.m3outline)
        readonly property color m3outlineVariant: root.layer(root.palette.m3outlineVariant)
        readonly property color m3shadow: root.layer(root.palette.m3shadow)
        readonly property color m3scrim: root.layer(root.palette.m3scrim)
        readonly property color m3surfaceTint: root.layer(root.palette.m3surfaceTint)
        readonly property color m3primary: root.layer(root.palette.m3primary)
        readonly property color m3onPrimary: root.layer(root.palette.m3onPrimary)
        readonly property color m3primaryContainer: root.layer(root.palette.m3primaryContainer)
        readonly property color m3onPrimaryContainer: root.layer(root.palette.m3onPrimaryContainer)
        readonly property color m3inversePrimary: root.layer(root.palette.m3inversePrimary)
        readonly property color m3secondary: root.layer(root.palette.m3secondary)
        readonly property color m3onSecondary: root.layer(root.palette.m3onSecondary)
        readonly property color m3secondaryContainer: root.layer(root.palette.m3secondaryContainer)
        readonly property color m3onSecondaryContainer: root.layer(root.palette.m3onSecondaryContainer)
        readonly property color m3tertiary: root.layer(root.palette.m3tertiary)
        readonly property color m3onTertiary: root.layer(root.palette.m3onTertiary)
        readonly property color m3tertiaryContainer: root.layer(root.palette.m3tertiaryContainer)
        readonly property color m3onTertiaryContainer: root.layer(root.palette.m3onTertiaryContainer)
        readonly property color m3error: root.layer(root.palette.m3error)
        readonly property color m3onError: root.layer(root.palette.m3onError)
        readonly property color m3errorContainer: root.layer(root.palette.m3errorContainer)
        readonly property color m3onErrorContainer: root.layer(root.palette.m3onErrorContainer)
        readonly property color m3success: root.layer(root.palette.m3success)
        readonly property color m3onSuccess: root.layer(root.palette.m3onSuccess)
        readonly property color m3successContainer: root.layer(root.palette.m3successContainer)
        readonly property color m3onSuccessContainer: root.layer(root.palette.m3onSuccessContainer)
        readonly property color m3primaryFixed: root.layer(root.palette.m3primaryFixed)
        readonly property color m3primaryFixedDim: root.layer(root.palette.m3primaryFixedDim)
        readonly property color m3onPrimaryFixed: root.layer(root.palette.m3onPrimaryFixed)
        readonly property color m3onPrimaryFixedVariant: root.layer(root.palette.m3onPrimaryFixedVariant)
        readonly property color m3secondaryFixed: root.layer(root.palette.m3secondaryFixed)
        readonly property color m3secondaryFixedDim: root.layer(root.palette.m3secondaryFixedDim)
        readonly property color m3onSecondaryFixed: root.layer(root.palette.m3onSecondaryFixed)
        readonly property color m3onSecondaryFixedVariant: root.layer(root.palette.m3onSecondaryFixedVariant)
        readonly property color m3tertiaryFixed: root.layer(root.palette.m3tertiaryFixed)
        readonly property color m3tertiaryFixedDim: root.layer(root.palette.m3tertiaryFixedDim)
        readonly property color m3onTertiaryFixed: root.layer(root.palette.m3onTertiaryFixed)
        readonly property color m3onTertiaryFixedVariant: root.layer(root.palette.m3onTertiaryFixedVariant)
    }

    component M3Palette: QtObject {
        property color m3primary_paletteKeyColor: "#a8627b"
        property color m3secondary_paletteKeyColor: "#8e6f78"
        property color m3tertiary_paletteKeyColor: "#986e4c"
        property color m3neutral_paletteKeyColor: "#807477"
        property color m3neutral_variant_paletteKeyColor: "#837377"
        property color m3background: "#191114"
        property color m3onBackground: "#efdfe2"
        property color m3surface: "#191114"
        property color m3surfaceDim: "#191114"
        property color m3surfaceBright: "#403739"
        property color m3surfaceContainerLowest: "#130c0e"
        property color m3surfaceContainerLow: "#22191c"
        property color m3surfaceContainer: "#261d20"
        property color m3surfaceContainerHigh: "#31282a"
        property color m3surfaceContainerHighest: "#3c3235"
        property color m3onSurface: "#efdfe2"
        property color m3surfaceVariant: "#514347"
        property color m3onSurfaceVariant: "#d5c2c6"
        property color m3inverseSurface: "#efdfe2"
        property color m3inverseOnSurface: "#372e30"
        property color m3outline: "#9e8c91"
        property color m3outlineVariant: "#514347"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#ffb0ca"
        property color m3primary: "#ffb0ca"
        property color m3onPrimary: "#541d34"
        property color m3primaryContainer: "#6f334a"
        property color m3onPrimaryContainer: "#ffd9e3"
        property color m3inversePrimary: "#8b4a62"
        property color m3secondary: "#e2bdc7"
        property color m3onSecondary: "#422932"
        property color m3secondaryContainer: "#5a3f48"
        property color m3onSecondaryContainer: "#ffd9e3"
        property color m3tertiary: "#f0bc95"
        property color m3onTertiary: "#48290c"
        property color m3tertiaryContainer: "#b58763"
        property color m3onTertiaryContainer: "#000000"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color m3primaryFixed: "#ffd9e3"
        property color m3primaryFixedDim: "#ffb0ca"
        property color m3onPrimaryFixed: "#39071f"
        property color m3onPrimaryFixedVariant: "#6f334a"
        property color m3secondaryFixed: "#ffd9e3"
        property color m3secondaryFixedDim: "#e2bdc7"
        property color m3onSecondaryFixed: "#2b151d"
        property color m3onSecondaryFixedVariant: "#5a3f48"
        property color m3tertiaryFixed: "#ffdcc3"
        property color m3tertiaryFixedDim: "#f0bc95"
        property color m3onTertiaryFixed: "#2f1500"
        property color m3onTertiaryFixedVariant: "#623f21"
        property color term0: "#353434"
        property color term1: "#ff4c8a"
        property color term2: "#ffbbb7"
        property color term3: "#ffdedf"
        property color term4: "#b3a2d5"
        property color term5: "#e98fb0"
        property color term6: "#ffba93"
        property color term7: "#eed1d2"
        property color term8: "#b39e9e"
        property color term9: "#ff80a3"
        property color term10: "#ffd3d0"
        property color term11: "#fff1f0"
        property color term12: "#dcbc93"
        property color term13: "#f9a8c2"
        property color term14: "#ffd1c0"
        property color term15: "#ffffff"
    }
}
