#include <QDBusMetaType>
#include <QQmlExtensionPlugin>
#include <QQmlEngine>
#include <qqml.h>
#include "sysmon.hpp"
#include "nixgen.hpp"
#include "polkitagent.hpp"
#include "hwprovider.hpp"
#include "systemdwatcher.hpp"

static QObject* sysmonSingletonFactory(QQmlEngine*, QJSEngine*) {
    return new SysmonProvider();
}

static QObject* nixgenSingletonFactory(QQmlEngine*, QJSEngine*) {
    return new NixGenProvider();
}

static QObject* polkitAgentFactory(QQmlEngine*, QJSEngine*) {
    return new PolkitAgent();
}

static QObject* hwProviderFactory(QQmlEngine*, QJSEngine*) {
    return new HwProvider();
}

static QObject* systemdWatcherFactory(QQmlEngine*, QJSEngine*) {
    return new SystemdWatcher();
}

class ShellQmlPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char* uri) override {
        qDBusRegisterMetaType<PolkitIdentity>();
        qmlRegisterSingletonType<SysmonProvider>(uri, 1, 0, "SysmonProvider", sysmonSingletonFactory);
        qmlRegisterSingletonType<NixGenProvider>(uri, 1, 0, "NixGenProvider", nixgenSingletonFactory);
        qmlRegisterSingletonType<PolkitAgent>(uri, 1, 0, "PolkitAgent", polkitAgentFactory);
        qmlRegisterSingletonType<HwProvider>(uri, 1, 0, "HwProvider", hwProviderFactory);
        qmlRegisterSingletonType<SystemdWatcher>(uri, 1, 0, "SystemdWatcher", systemdWatcherFactory);
    }
};

#include "plugin.moc"
