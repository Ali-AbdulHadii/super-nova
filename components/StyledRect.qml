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
        // Glass light belongs to a body. A rect with a transparent fill has none, so a
        // rim there outlines nothing -- it reads as a stray border around empty space.
        // Tracking the alpha also fades the rim in with a fill that animates.
        active: root.glassCard && root.color.a > 0 && Colours.glass.cardsIn(root.Window.window)
        opacity: root.color.a

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
