pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Components
import qs.services

Item {
    id: root

    property real radius
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomRightRadius: radius
    property real bottomLeftRadius: radius
    property color color: "transparent"

    // Opt-in: this rect is a card or button that takes the glass rim and light when
    // the glass style reaches cards in its window (see Colours.glass.cardsIn)
    property bool glassCard

    default property alias contentData: contentItem.data

    Item {
        id: contentItem

        anchors.fill: parent
    }

    ShaderEffectSource {
        id: source

        hideSource: true
        sourceItem: contentItem
    }

    RoundedMask {
        anchors.fill: parent
        source: source
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomRightRadius: root.bottomRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        color: root.color
    }

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
