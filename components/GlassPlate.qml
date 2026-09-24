import QtQuick

// Realistic glass body for one rounded rectangle (glassplate.frag): lenses the part of
// sourceItem under backdropRect, which must be exactly what lies behind this item.
ShaderEffect {
    id: root

    required property Item sourceItem
    required property rect backdropRect
    required property real plateRadius
    property real refraction: 0.6
    property real dispersion: 0.5

    readonly property vector2d plateSize: Qt.vector2d(width, height)
    readonly property ShaderEffectSource backdrop: backdropTex

    fragmentShader: "qrc:/shaders/glassplate.frag.qsb"

    // Zero-sized, so it only provides the texture and draws nothing itself
    ShaderEffectSource {
        id: backdropTex

        sourceItem: root.sourceItem
        sourceRect: root.backdropRect
    }
}
