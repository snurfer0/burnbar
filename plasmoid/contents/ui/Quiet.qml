import QtQuick
import org.kde.kirigami as Kirigami

// Small, dim, spaced-out text for captions next to a value.
Text {
    color: Kirigami.Theme.textColor
    opacity: 0.45
    font.family: Kirigami.Theme.defaultFont.family
    font.pixelSize: 10
    font.weight: Font.DemiBold
    font.letterSpacing: 0.6
}
