import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.launcher.services

// A ">file" result: icon by type, name, and the folder it's in. Enter or a click opens
// it; the trailing button shows it in its folder.
Item {
    id: root

    required property var modelData
    required property var list

    readonly property string suffix: {
        const name = modelData?.name ?? "";
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
    }
    readonly property string icon: {
        if (modelData?.isDir)
            return "folder";
        const kinds = [[["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "avif", "heic", "tiff"], "image"], [["mp4", "mkv", "webm", "mov", "avi"], "movie"], [["mp3", "flac", "wav", "ogg", "opus", "m4a"], "music_note"], [["pdf"], "picture_as_pdf"], [["doc", "docx", "odt", "rtf", "txt", "md", "pages"], "description"], [["xls", "xlsx", "ods", "csv"], "table_chart"], [["ppt", "pptx", "odp", "key"], "slideshow"], [["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"], "folder_zip"], [["js", "ts", "py", "qml", "cpp", "hpp", "c", "h", "rs", "go", "java", "kt", "lua", "sh", "json", "html", "css", "toml", "yaml", "yml"], "code"]];
        for (const [exts, glyph] of kinds)
            if (exts.includes(suffix))
                return glyph;
        return "draft";
    }

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.modelData?.onClicked(root.list)
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        MaterialIcon {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.builders.large.scale(1.3).build()
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: reveal.left
            anchors.rightMargin: Tokens.spacing.small
            anchors.verticalCenter: icon.verticalCenter

            implicitHeight: name.implicitHeight + folder.implicitHeight

            StyledText {
                id: name

                anchors.left: parent.left
                anchors.right: parent.right
                text: root.modelData?.name ?? ""
                font: Tokens.font.body.medium
                elide: Text.ElideMiddle
            }

            StyledText {
                id: folder

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: name.bottom
                text: Paths.shortenHome(root.modelData?.parentDir ?? "")
                font: Tokens.font.body.small
                color: Colours.palette.m3outline
                elide: Text.ElideMiddle
            }
        }

        Item {
            id: reveal

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: revealIcon.implicitWidth + Tokens.padding.small * 2
            implicitHeight: implicitWidth

            StateLayer {
                radius: Tokens.rounding.full
                onClicked: Files.reveal(root.list, root.modelData?.path ?? "")
            }

            MaterialIcon {
                id: revealIcon

                anchors.centerIn: parent
                text: "folder_open"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }
        }
    }
}
