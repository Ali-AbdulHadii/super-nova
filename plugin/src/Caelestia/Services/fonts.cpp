#include "fonts.hpp"

#include <qfontdatabase.h>

#include <algorithm>

namespace caelestia::services {

namespace {

// Qt disambiguates same-named families with a foundry suffix ("Times [Adobe]").
// Nothing outside Qt understands that syntax, so publish plain names only.
QString stripFoundry(const QString& family) {
    if (!family.endsWith(u']')) {
        return family;
    }

    const auto idx = family.lastIndexOf(u'[');
    if (idx <= 0) {
        return family;
    }

    return family.left(idx).trimmed();
}

// Emoji, powerline and dingbat fonts are in the database but are not text fonts,
// so they have no business in a font picker.
bool isTextFamily(const QString& family) {
    const auto systems = QFontDatabase::writingSystems(family);
    if (systems.isEmpty()) {
        return false;
    }

    return systems.size() > 1 || systems.first() != QFontDatabase::Symbol;
}

} // namespace

Fonts::Fonts(QObject* parent)
    : QObject(parent) {
    // QML_SINGLETON constructs on first access, which is the first time the fonts
    // page is opened. One pass over the already-populated font database.
    populate();
}

QStringList Fonts::families() const {
    return m_families;
}

QStringList Fonts::monoFamilies() const {
    return m_monoFamilies;
}

bool Fonts::isInstalled(const QString& family) const {
    return !family.isEmpty() && m_families.contains(family);
}

void Fonts::refresh() {
    populate();
    emit familiesChanged();
}

void Fonts::populate() {
    m_families.clear();
    m_monoFamilies.clear();

    for (const auto& raw : QFontDatabase::families()) {
        if (!isTextFamily(raw)) {
            continue;
        }

        const auto name = stripFoundry(raw);
        if (name.isEmpty() || m_families.contains(name)) {
            continue;
        }

        m_families.append(name);

        // Checked against the Qt-native name, before the foundry suffix is stripped
        if (QFontDatabase::isFixedPitch(raw)) {
            m_monoFamilies.append(name);
        }
    }

    const auto byLocale = [](const QString& a, const QString& b) {
        return a.localeAwareCompare(b) < 0;
    };
    std::ranges::sort(m_families, byLocale);
    std::ranges::sort(m_monoFamilies, byLocale);
}

} // namespace caelestia::services
