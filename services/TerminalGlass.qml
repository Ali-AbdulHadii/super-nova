pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

// Glass for terminal windows, with its own settings (appearance.glass.terminals):
// foot and kitty background opacity, keeping text crisp, plus a light Hyprland border
// as the rim. The shell can't draw on other apps, so this edits exactly one setting
// in each terminal's config: foot's alpha= lines and kitty's background_opacity line.
// The values found there are saved first and written back when switched off.
Singleton {
    id: root

    readonly property bool enabled: Tokens.glass.terminals.enabled
    readonly property real opacity: Math.max(0.3, Math.min(1, Tokens.glass.terminals.opacity))
    readonly property bool rim: Tokens.glass.terminals.rim
    readonly property real rimOpacity: Math.max(0, Math.min(1, Tokens.glass.terminals.rimOpacity))

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`
    property bool footReady
    property bool kittyReady
    property bool stateReady
    property var saved: ({})

    function format(value: real): string {
        return Math.max(0.3, Math.min(1, value)).toFixed(2);
    }

    // foot keeps alpha in [colors-dark] / [colors-light] (or [colors] before 1.22)
    function isFootColours(section: string): bool {
        return section === "colors-dark" || section === "colors-light" || section === "colors";
    }

    function footAlpha(text: string): var {
        let section = "";
        for (const line of text.split("\n")) {
            const header = line.match(/^\s*\[([^\]]+)\]/);
            if (header) {
                section = header[1].trim();
                continue;
            }
            const m = line.match(/^\s*alpha\s*=\s*(\S+)/);
            if (m && isFootColours(section))
                return m[1];
        }
        return null;
    }

    // value null removes the alpha lines this service added
    function setFootAlpha(text: string, value: var): string {
        const lines = text.split("\n");
        const out = [];
        let section = "";
        let found = false;
        let colourHeader = -1;
        for (const line of lines) {
            const header = line.match(/^\s*\[([^\]]+)\]/);
            if (header) {
                section = header[1].trim();
                out.push(line);
                if (colourHeader < 0 && isFootColours(section))
                    colourHeader = out.length - 1;
                continue;
            }
            if (isFootColours(section) && /^\s*alpha\s*=/.test(line)) {
                found = true;
                // Only the value changes, so the line's own spacing survives a round trip
                if (value !== null)
                    out.push(line.replace(/^(\s*alpha\s*=\s*)\S*/, `$1${value}`));
                continue;
            }
            out.push(line);
        }
        if (!found && value !== null) {
            if (colourHeader >= 0)
                out.splice(colourHeader + 1, 0, `alpha=${value}`);
            else
                out.push("", "[colors-dark]", `alpha=${value}`);
        }
        return out.join("\n");
    }

    function kittyOpacity(text: string): var {
        for (const line of text.split("\n")) {
            const m = line.match(/^\s*background_opacity\s+(\S+)/);
            if (m)
                return m[1];
        }
        return null;
    }

    function setKittyOpacity(text: string, value: var): string {
        const lines = text.split("\n");
        const out = [];
        let found = false;
        for (const line of lines) {
            if (/^\s*background_opacity\s/.test(line)) {
                found = true;
                if (value !== null)
                    out.push(line.replace(/^(\s*background_opacity\s+)\S*/, `$1${value}`));
                continue;
            }
            out.push(line);
        }
        if (!found && value !== null)
            out.push(`background_opacity ${value}`);
        return out.join("\n");
    }

    function writeFoot(value: var): void {
        const current = footFile.text();
        const next = setFootAlpha(current, value);
        if (next !== current)
            footFile.setText(next);
    }

    function writeKitty(value: var): void {
        const current = kittyFile.text();
        const next = setKittyOpacity(current, value);
        if (next !== current) {
            kittyFile.setText(next);
            // kitty rereads its config on SIGUSR1, so open windows update too
            Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
        }
    }

    function apply(): void {
        if (!stateReady)
            return;

        if (enabled) {
            // Remember what the terminals had before the first change
            if (!("foot" in saved) && !("kitty" in saved)) {
                saved = {
                    foot: footReady ? footAlpha(footFile.text()) : null,
                    kitty: kittyReady ? kittyOpacity(kittyFile.text()) : null
                };
                stateFile.setText(JSON.stringify(saved));
            }
            if (footReady)
                writeFoot(format(opacity));
            if (kittyReady)
                writeKitty(format(opacity));
        } else if ("foot" in saved || "kitty" in saved) {
            if (footReady)
                writeFoot(saved.foot ?? null);
            if (kittyReady)
                writeKitty(saved.kitty ?? null);
            saved = {};
            stateFile.setText("{}");
        }

        applyRules();
    }

    function applyRules(): void {
        if (!Hypr.usingLua)
            return;
        const alpha = Math.round(rimOpacity * 255).toString(16).padStart(2, "0");
        const match = `match = { class = "^(foot|kitty)$" }`;
        const msgs = [`eval hl.window_rule({ name = "caelestia-terminal-glass", enabled = ${enabled && rim}, ${match}, border_color = "rgba(ffffff${alpha})" })`];
        // With the hyprliquid plugin loaded, terminals also refract what is behind them
        if (Colours.glass.pluginPresent)
            msgs.push(`eval hl.window_rule({ name = "caelestia-terminal-liquid", enabled = ${enabled}, ${match}, ["hyprliquid:effect"] = "liquid_glass" })`);
        Hypr.extras.batchMessage(msgs);
    }

    onEnabledChanged: applyTimer.restart()
    onOpacityChanged: applyTimer.restart()
    onRimChanged: applyTimer.restart()
    onRimOpacityChanged: applyTimer.restart()

    // Coalesce slider drags into one write
    Timer {
        id: applyTimer

        interval: 300
        onTriggered: root.apply()
    }

    Connections {
        function onConfigReloaded(): void {
            root.applyRules();
        }

        target: Hypr
    }

    FileView {
        id: footFile

        path: `${root.configHome}/foot/foot.ini`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.footReady = true;
            applyTimer.restart();
        }
        onLoadFailed: root.footReady = false
    }

    FileView {
        id: kittyFile

        path: `${root.configHome}/kitty/kitty.conf`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.kittyReady = true;
            applyTimer.restart();
        }
        onLoadFailed: root.kittyReady = false
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/terminal-glass.json`
        printErrors: false
        onLoaded: {
            try {
                root.saved = JSON.parse(text()) ?? {};
            } catch (e) {
                root.saved = {};
            }
            root.stateReady = true;
            applyTimer.restart();
        }
        onLoadFailed: {
            root.saved = {};
            root.stateReady = true;
            applyTimer.restart();
        }
    }
}
