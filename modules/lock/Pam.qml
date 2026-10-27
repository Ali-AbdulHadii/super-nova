pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Caelestia.Config
import Caelestia.Services

Scope {
    id: root

    enum PamState {
        None,
        Error,
        MaxTries,
        Failed
    }

    required property WlSessionLock lock

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    readonly property alias howdy: howdy

    property string lockMessage
    property int state
    property string buffer

    // Activity (pointer movement, non-text keys) starts a face scan, like raise to wake.
    // Disarmed after each scan until the user has been still for a while, so a failed scan
    // isn't retried on every mouse move, and briefly after locking, so the movement that
    // locked the screen doesn't unlock it again
    property bool autoScanArmed

    signal flashMsg

    function wake(): void {
        if (autoScanArmed && buffer.length === 0 && !passwd.active && howdy.canAttempt && !howdy.active) {
            autoScanArmed = false;
            autoScanRearm.interval = 10000;
            howdy.start();
        }

        if (!autoScanArmed)
            autoScanRearm.restart();
    }

    function handleKey(event: KeyEvent): void {
        if (passwd.active)
            return;

        // Non-text keys (Shift, Ctrl, arrows, Esc) wake a scan without touching the password
        if (buffer.length === 0 && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && event.key !== Qt.Key_Backspace && !/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text))
            return wake();

        // Trigger howdy on enter while empty buffer
        if (howdy.canAttempt && !howdy.active && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && buffer.length === 0)
            return howdy.start(); // Gate on active so double enter still allows empty password

        if (state === Pam.MaxTries)
            return;

        // Abort howdy on pwd input
        if (howdy.active)
            howdy.abort();

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            passwd.start();
        } else if (event.key === Qt.Key_Backspace) {
            if (event.modifiers & Qt.ControlModifier) {
                buffer = "";
            } else {
                buffer = buffer.slice(0, -1);
            }
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            // Allow anything except control characters
            buffer += event.text;
        }
    }

    function restartFprint(): void {
        fprint.reset();
        if (fprint.canAttempt)
            fprint.start();
        else
            fprint.abort();
    }

    function clearTransientState(): void {
        for (const obj of [root, fprint, howdy])
            if (obj.state !== Pam.MaxTries)
                obj.state = Pam.None;
    }

    PamContext {
        id: passwd

        config: "passwd"
        configDirectory: Quickshell.shellPath("assets/pam.d")

        onMessageChanged: {
            if (message.startsWith("The account is locked"))
                root.lockMessage = message;
            else if (root.lockMessage && message.endsWith(" left to unlock)"))
                root.lockMessage += "\n" + message;
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;

            respond(root.buffer);
            root.buffer = "";
        }

        onCompleted: res => {
            if (res === PamResult.Success)
                return root.lock.unlock();

            root.clearTransientState();

            if (res === PamResult.Error)
                root.state = Pam.Error;
            else if (res === PamResult.MaxTries)
                root.state = Pam.MaxTries;
            else if (res === PamResult.Failed)
                root.state = Pam.Failed;

            root.flashMsg();
            pwdStateReset.restart();
        }
    }

    // Any input after a moment of stillness wakes a face scan. The compositor reports it,
    // so it covers every screen and works while the displays are still off
    IdleMonitor {
        enabled: root.lock.secure
        timeout: 1
        respectInhibitors: false
        onIsIdleChanged: {
            if (!isIdle)
                root.wake();
        }
    }

    Timer {
        id: autoScanRearm

        onTriggered: root.autoScanArmed = true
    }

    Timer {
        id: pwdStateReset

        interval: 4000
        onTriggered: {
            if (root.state !== Pam.MaxTries)
                root.state = Pam.None;
        }
    }

    ManualPamContext {
        id: fprint

        config: "fprint"
        availCommand: ["sh", "-c", "fprintd-list $USER"]
        retryOnFail: true
        enabled: GlobalConfig.lock.enableFprint
        maxTries: GlobalConfig.lock.maxFprintTries
        onAvailProcExited: root.restartFprint()
    }

    ManualPamContext {
        id: howdy

        config: "howdy"
        availCommand: ["sh", "-c", "command -v howdy"]
        enabled: GlobalConfig.lock.enableHowdy
        maxTries: GlobalConfig.lock.maxHowdyTries
    }

    Connections {
        function onResumed(): void {
            if (howdy.canAttempt && !howdy.active && GlobalConfig.lock.triggerHowdyOnWake)
                howdy.start();
        }

        target: SessionManager
    }

    Connections {
        function onSecureChanged(): void {
            if (root.lock.secure) {
                fprint.checkAvailable();
                howdy.checkAvailable();
                fprint.reset();
                howdy.reset();
                root.buffer = "";
                root.state = Pam.None;
                root.lockMessage = "";
                root.autoScanArmed = false;
                autoScanRearm.interval = 1500;
                autoScanRearm.restart();
            }
        }

        function onUnlock(): void {
            fprint.abort();
            howdy.abort();
            passwd.abort();
        }

        target: root.lock
    }

    Connections {
        function onEnableFprintChanged(): void {
            root.restartFprint();
        }

        function onEnableHowdyChanged(): void {
            if (!GlobalConfig.lock.enableHowdy && howdy.active)
                howdy.abort();
        }

        target: GlobalConfig.lock
    }

    component ManualPamContext: Scope {
        id: ctx

        required property bool enabled
        required property int maxTries
        property alias config: pam.config
        property alias availCommand: availProc.command
        property bool retryOnFail

        property bool available
        property int tries
        property int errorTries
        property int state
        readonly property bool canAttempt: available && enabled && root.lock.secure && tries < maxTries

        readonly property alias active: pam.active
        readonly property alias message: pam.message

        signal availProcExited(code: int)

        function checkAvailable(): void {
            availProc.running = true;
        }

        function start(): void {
            pam.start();
        }

        function abort(): void {
            pam.abort();
        }

        function reset(): void {
            tries = 0;
            errorTries = 0;
            state = Pam.None;
        }

        PamContext {
            id: pam

            configDirectory: Quickshell.shellPath("assets/pam.d")

            onCompleted: res => {
                if (!ctx.available)
                    return;

                if (res === PamResult.Success)
                    return root.lock.unlock();

                root.clearTransientState();

                if (res === PamResult.Error) {
                    ctx.state = Pam.Error;
                    ctx.errorTries++;
                    if (ctx.errorTries < 5) {
                        abort();
                        errorRetry.restart();
                    }
                } else if (res === PamResult.MaxTries || res === PamResult.Failed) {
                    ctx.tries++;
                    if (ctx.tries < ctx.maxTries) {
                        ctx.state = Pam.Failed;
                        if (ctx.retryOnFail)
                            start();
                    } else {
                        ctx.state = Pam.MaxTries;
                        abort();
                    }
                }

                root.flashMsg();
                stateReset.restart();
            }
        }

        Timer {
            id: errorRetry

            interval: 800
            onTriggered: pam.start()
        }

        Timer {
            id: stateReset

            interval: 4000
            onTriggered: {
                if (ctx.state !== Pam.MaxTries)
                    ctx.state = Pam.None;
                ctx.errorTries = 0;
            }
        }

        Process {
            id: availProc

            onExited: code => {
                ctx.available = code === 0;
                ctx.availProcExited(code);
            }
        }
    }
}
