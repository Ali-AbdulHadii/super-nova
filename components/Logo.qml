import QtQuick
import QtQuick.Shapes
import qs.services

// The Apocrypha mark: three bars forming an impossible triangle. Geometry is
// verbatim from Apocrypha's docs/images/logo.svg, translated to the mark's own
// bounds so it centres without the source's empty margin.
//
// Brand rule: one colour, taken from whatever the mark sits on -- the text
// colour of that surface, never an accent. Callers on a tinted surface pass
// that surface's "on" colour.
Item {
    id: root

    readonly property real designWidth: 25.6
    readonly property real designHeight: 22.32

    property color colour: Colours.palette.m3onSurface

    implicitWidth: designWidth
    implicitHeight: designHeight

    Shape {
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.Center
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.colour
            strokeColor: "transparent"

            PathSvg {
                path: "M4.12 22.32 21.98 22.32 25.08 16.96 7.22 16.96Z"
            }
        }

        ShapePath {
            fillColor: root.colour
            strokeColor: "transparent"

            PathSvg {
                path: "M8.93 0.29 0.00 15.76 3.09 21.12 12.02 5.65Z"
            }
        }

        ShapePath {
            fillColor: root.colour
            strokeColor: "transparent"

            PathSvg {
                path: "M25.60 15.47 16.67 0.00 10.48 0.00 19.41 15.47Z"
            }
        }
    }
}
