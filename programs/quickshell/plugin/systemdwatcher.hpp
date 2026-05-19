#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class SystemdWatcher : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool proxyActive READ proxyActive NOTIFY proxyActiveChanged)

public:
    explicit SystemdWatcher(QObject* parent = nullptr);
    bool proxyActive() const { return m_proxyActive; }

signals:
    void proxyActiveChanged();

private slots:
    void onPropertiesChanged(const QString& iface,
                              const QVariantMap& changed,
                              const QStringList& invalidated);

private:
    void queryInitialState();
    bool m_proxyActive = false;
};
