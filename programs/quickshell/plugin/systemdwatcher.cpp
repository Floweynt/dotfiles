#include "systemdwatcher.hpp"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusVariant>

static constexpr auto SYSTEMD_SVC = "org.freedesktop.systemd1";
static constexpr auto MANAGER_PATH = "/org/freedesktop/systemd1";
static constexpr auto MANAGER_IFACE = "org.freedesktop.systemd1.Manager";
static constexpr auto UNIT_IFACE = "org.freedesktop.systemd1.Unit";
static constexpr auto PROXY_PATH = "/org/freedesktop/systemd1/unit/proxy_2eservice";
static constexpr auto PROPS_IFACE = "org.freedesktop.DBus.Properties";

SystemdWatcher::SystemdWatcher(QObject* parent) : QObject(parent)
{
    auto bus = QDBusConnection::systemBus();

    // Tell systemd to emit signals to this connection
    bus.call(QDBusMessage::createMethodCall(SYSTEMD_SVC, MANAGER_PATH, MANAGER_IFACE, "Subscribe"));

    bus.connect(SYSTEMD_SVC, PROXY_PATH, PROPS_IFACE, "PropertiesChanged", this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));

    queryInitialState();
}

void SystemdWatcher::onPropertiesChanged(const QString& iface, const QVariantMap& changed, const QStringList& invalidated)
{
    if (iface != QLatin1String(UNIT_IFACE))
        return;

    if (changed.contains("ActiveState"))
    {
        const bool active = changed.value("ActiveState").toString() == "active";
        if (active == m_proxyActive)
            return;
        m_proxyActive = active;
        emit proxyActiveChanged();
    }
    else if (invalidated.contains("ActiveState"))
    {
        queryInitialState();
    }
}

void SystemdWatcher::queryInitialState()
{
    QDBusMessage req = QDBusMessage::createMethodCall(SYSTEMD_SVC, PROXY_PATH, PROPS_IFACE, "Get");
    const QDBusMessage reply = QDBusConnection::systemBus().call(req << QString(UNIT_IFACE) << QString("ActiveState"));

    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
        return;

    const bool active = reply.arguments().first().value<QDBusVariant>().variant().toString() == "active";
    if (active == m_proxyActive)
        return;
    m_proxyActive = active;
    emit proxyActiveChanged();
}
