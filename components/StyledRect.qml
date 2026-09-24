pragma ComponentBehavior: Bound

import QtQuick
import qs.services

Rectangle {
    id: root

    // Opt-in: this rect is a card or button that takes the glass rim and light when
    // the glass style reaches cards in its window (see Colours.glass.cardsIn)
    property bool glassCard

    color: "transparent"

    Loader {
        anchors.fill: parent
        active: root.glassCard && Colours.glass.cardsIn(root.Window.window)

        sourceComponent: GlassRim {
            topLeft: root.topLeftRadius
            topRight: root.topRightRadius
            bottomRight: root.bottomRightRadius
            bottomLeft: root.bottomLeftRadius
        }
    }

    Behavior on color {
        CAnim {}
    }
}
