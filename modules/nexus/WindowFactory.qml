pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    // The open Nexus window, if any. QML nulls this when the window destroys itself.
    property FloatingWindow window: null

    // Apocrypha: open Nexus at most once. Every caller (Super+I, the IPC call, the
    // utilities toggle, the drawer's pop-out button) focuses the existing window
    // instead of stacking another copy.
    function create(parent: Item, props: var): void {
        if (window) {
            focusWindow();
            return;
        }
        window = nexusComp.createObject(parent ?? dummy, props);
    }

    function focusWindow(): void {
        // Matched by title: the file dialog is the shell's only other floating
        // window and never carries Nexus's title.
        const toplevel = Hypr.toplevels.values.find(t => t.title === window.title);
        if (!toplevel)
            return;
        const address = `0x${toplevel.address}`;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:${address}" })` : `focuswindow address:${address}`);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
            minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: Tr.tr("Nexus — %1").arg(PageRegistry.pages[nexus.nState.currentPageIdx].label)

            Nexus {
                id: nexus

                anchors.fill: parent
                nState.screen: win.screen
                nState.isWindow: true
                onClose: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
