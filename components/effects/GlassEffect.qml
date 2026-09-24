import QtQuick
import QtQuick.Effects

// Liquid Glass compositor, used as the layer.effect of a BlobGroup in glass mode.
// The layer holds light data from blob.frag; glass.frag turns it into a tinted,
// lit, translucent surface with a soft shadow outside the shape.
ShaderEffect {
    id: root

    property Item source
    property color tint: "transparent"
    property color shadowColour: "transparent"
    property real highlight: 0.85
    property real lightMode
    property vector2d shadowOffset: Qt.vector2d(0, 3 / Math.max(1, height))
    readonly property ShaderEffectSource shadowSource: shadowTex

    fragmentShader: "qrc:/shaders/glass.frag.qsb"

    // Blurred copy of the coverage, sampled for the shadow
    MultiEffect {
        id: shadowBlur

        anchors.fill: parent
        source: root.source
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 32
    }

    ShaderEffectSource {
        id: shadowTex

        sourceItem: shadowBlur
        hideSource: true
    }
}
