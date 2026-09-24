pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.components.images

// Liquid Glass compositor, used as the layer.effect of a BlobGroup in glass mode.
// The layer holds edge geometry from blob.frag; glass.frag lights it, and in
// realistic mode lenses the wallpaper through it, with a soft shadow outside.
ShaderEffect {
    id: root

    property Item source
    property color tint: "transparent"
    property color shadowColour: "transparent"
    property real highlight: 0.85
    property real lightMode
    property vector2d shadowOffset: Qt.vector2d(0, 3 / Math.max(1, height))

    // Realistic mode draws the body from the wallpaper. The window this effect
    // covers must sit at the screen origin, as the wallpaper window does.
    property string wallpaperPath
    property bool realisticEnabled
    property real refraction: 0.6
    property real dispersion: 0.5
    // Apple glass: clear body, white rim and inner band, no shadow
    property real apple

    readonly property WallTextures textures: wallLoader.item as WallTextures
    readonly property real realistic: textures?.ready ? 1 : 0
    readonly property vector2d targetSize: Qt.vector2d(width, height)
    readonly property ShaderEffectSource shadowSource: shadowTex
    // Unused by the shader outside realistic mode, but every sampler needs a texture
    readonly property Item wallpaper: textures?.sharp ?? source
    readonly property Item wallpaperBlur: textures?.blurred ?? source

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

    // Sharp and frosted wallpaper textures, only while realistic mode needs them.
    // They are static, so they re-render only when the wallpaper changes.
    Loader {
        id: wallLoader

        anchors.fill: parent
        active: root.realisticEnabled && root.wallpaperPath !== ""

        sourceComponent: WallTextures {
            path: root.wallpaperPath
        }
    }

    component WallTextures: Item {
        id: wallTextures

        required property string path
        readonly property bool ready: wallImg.status === Image.Ready
        readonly property ShaderEffectSource sharp: sharpTex
        readonly property ShaderEffectSource blurred: blurTex

        CachingImage {
            id: wallImg

            anchors.fill: parent
            path: wallTextures.path
        }

        ShaderEffectSource {
            id: sharpTex

            sourceItem: wallImg
            hideSource: true
        }

        MultiEffect {
            id: wallBlur

            anchors.fill: parent
            source: wallImg
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 0.8
            blurMax: 64
        }

        ShaderEffectSource {
            id: blurTex

            sourceItem: wallBlur
            hideSource: true
        }
    }
}
