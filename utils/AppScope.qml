pragma Singleton

import Quickshell

// Apps the shell starts inherit its own cgroup, which is the compositor's. One hungry
// app then has systemd-oomd kill the whole session instead of just that app, which is
// what took the desktop down twice on 21 Oct. uwsm gives each app its own scope under
// app.slice, so the kill lands on the app. Keybinds already launch this way.
Singleton {
    id: root

    // uwsm exports this into every process of a session it manages
    readonly property bool available: !!Quickshell.env("UWSM_FINALIZE_VARNAMES")

    // A command, in its own scope where the session allows it
    function wrap(command: list<string>): list<string> {
        return available ? ["uwsm", "app", "--", ...command] : command;
    }

    // A desktop entry by id, which is how uwsm names the unit and reads the entry's
    // own metadata. uwsm wants the file name, and an id never carries the suffix even
    // when it ends in one: "org.telegram.desktop" lives in org.telegram.desktop.desktop.
    function entryCommand(id: string): list<string> {
        return ["uwsm", "app", "--", `${id}.desktop`];
    }
}
