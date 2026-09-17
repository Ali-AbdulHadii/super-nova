import QtQuick
import qs.components

// The About page's Apocrypha mark. It fades in once when the page opens and
// then holds still: motion here only answers "where did this come from".
// Upstream's spin, blur and perpetually drifting stars were decoration, which
// Apocrypha's design language removes.
Logo {
    id: root

    implicitWidth: 96
    implicitHeight: 96 * designHeight / designWidth

    Anim on opacity {
        type: Anim.DefaultEffects
        from: 0
        to: 1
    }
}
