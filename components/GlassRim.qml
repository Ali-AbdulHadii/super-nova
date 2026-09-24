import QtQuick
import qs.services

// Glass light on one rounded rectangle (glassrim.frag), used by StyledRect and
// StyledClippingRect when they are glass cards. Light only, no body.
ShaderEffect {
    required property real topLeft
    required property real topRight
    required property real bottomRight
    required property real bottomLeft

    readonly property vector2d rimSize: Qt.vector2d(width, height)
    readonly property vector4d radii: Qt.vector4d(topLeft, topRight, bottomRight, bottomLeft)
    readonly property real highlight: Colours.glass.highlight
    readonly property real apple: Colours.glass.apple ? 1 : 0

    anchors.fill: parent
    fragmentShader: "qrc:/shaders/glassrim.frag.qsb"
}
