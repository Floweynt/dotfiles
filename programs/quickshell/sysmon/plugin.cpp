#include <QQmlExtensionPlugin>
#include <QQmlEngine>
#include <qqml.h>
#include "sysmon.hpp"
#include "nixgen.hpp"

static QObject* sysmonSingletonFactory(QQmlEngine*, QJSEngine*) {
    return new SysmonProvider();
}

static QObject* nixgenSingletonFactory(QQmlEngine*, QJSEngine*) {
    return new NixGenProvider();
}

class SysmonQmlPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char* uri) override {
        qmlRegisterSingletonType<SysmonProvider>(uri, 1, 0, "SysmonProvider", sysmonSingletonFactory);
        qmlRegisterSingletonType<NixGenProvider>(uri, 1, 0, "NixGenProvider", nixgenSingletonFactory);
    }
};

#include "plugin.moc"
