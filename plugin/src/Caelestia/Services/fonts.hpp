#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstringlist.h>

namespace caelestia::services {

class Fonts : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QStringList families READ families NOTIFY familiesChanged FINAL)
    Q_PROPERTY(QStringList monoFamilies READ monoFamilies NOTIFY familiesChanged FINAL)

public:
    explicit Fonts(QObject* parent = nullptr);

    [[nodiscard]] QStringList families() const;
    [[nodiscard]] QStringList monoFamilies() const;

    // The only gate between the picker and the config file
    Q_INVOKABLE [[nodiscard]] bool isInstalled(const QString& family) const;
    Q_INVOKABLE void refresh();

signals:
    void familiesChanged();

private:
    void populate();

    QStringList m_families;
    QStringList m_monoFamilies;
};

} // namespace caelestia::services
